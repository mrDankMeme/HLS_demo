//
//  HLSDownloadManager.swift
//  HLSDemo2
//
//  Updated by Niiaz Khasanov on 10/18/25
//

import Foundation
import AVFoundation

protocol HLSDownloadManaging: AnyObject {
    /// Предзагрузить на диск не менее targetSeconds секунд; если ролик короче — меньше.
    func prefetch(videoID: Int, url: URL, targetSeconds: Double)
    /// Вернуть AVURLAsset, который прозрачно читает из оффлайн-кеша (если есть).
    func localAsset(for url: URL) -> AVURLAsset
    /// Сколько секунд реально лежит на диске для данного видео (best-effort).
    func prefetchedSeconds(for videoID: Int) -> Double
    /// Список videoID, по которым есть оффлайн-сегменты (>0 сек).
    func cachedVideoIDs() -> [Int]
    /// Снимок кэша: [videoID: seconds].
    func cachedSummary() -> [Int: Double]
    /// Помечено как некешируемое (например, сервер/формат не поддерживает оффлайн).
    func isNotCacheable(videoID: Int) -> Bool
}

final class HLSDownloadManager: NSObject, HLSDownloadManaging {
    static let shared = HLSDownloadManager()

    // MARK: Controls
    private let maxConcurrentDownloads = 10
    private let gate = DispatchSemaphore(value: 10)
    private let syncQ = DispatchQueue(label: "hls.download.manager.sync")

    // MARK: URLSession
    private lazy var configuration: URLSessionConfiguration = {
        let cfg = URLSessionConfiguration.background(withIdentifier: "ru.interesno.hlscache")
        cfg.allowsExpensiveNetworkAccess = true
        cfg.allowsConstrainedNetworkAccess = true
        return cfg
    }()

    private lazy var session: AVAssetDownloadURLSession = {
        AVAssetDownloadURLSession(configuration: configuration,
                                  assetDownloadDelegate: self,
                                  delegateQueue: OperationQueue())
    }()

    // MARK: State
    private var tasksByVideoID: [Int: AVAssetDownloadTask] = [:]
    private var targetsByTask: [Int: Double] = [:] // taskIdentifier → seconds
    private var prefetchedByVideoID: [Int: Double] = [:] // videoID → seconds
    private var lruOrder: [Int] = [] // LRU для активных задач
    private var notCacheableIDs: Set<Int> = [] // сюда попадают id с постоянными ошибками

    // Заголовки (пробрасываем в сегменты)
    private var defaultHeaders: [String: String] = [
        "User-Agent": "HLSDemo2/1.0 (iOS)",
        "Accept": "application/vnd.apple.mpegurl, application/x-mpegURL, */*"
    ]
    // Если нужны куки/авторизация — добавь здесь или через публичный setter:
    func setAuthHeaders(_ headers: [String: String]) {
        syncQ.async { [headers] in
            for (k, v) in headers { self.defaultHeaders[k] = v }
        }
    }

    // MARK: Public API

    func prefetch(videoID: Int, url: URL, targetSeconds: Double) {
        syncQ.async {
            if self.notCacheableIDs.contains(videoID) {
                // больше не пытаемся — формат/сервер не разрешает
                return
            }
            if let _ = self.tasksByVideoID[videoID] {
                self.bumpLRU(videoID)
                print("⏳ prefetch already running videoID=\(videoID)")
                return
            }

            self.enforceLRULimit()

            // ВАЖНО: пробрасываем HTTP заголовки
            let asset = AVURLAsset(url: url,
                                   options: [ "AVURLAssetHTTPHeaderFieldsKey": self.defaultHeaders ])

            // минимальный битрейт — чтобы старт был не «кашей»
            let options: [String: Any] = [
                AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 100_000
            ]

            guard let task = self.session.makeAssetDownloadTask(
                asset: asset,
                assetTitle: "video-\(videoID)",
                assetArtworkData: nil,
                options: options
            ) else {
                print("❌ makeAssetDownloadTask failed videoID=\(videoID)")
                self.notCacheableIDs.insert(videoID)
                return
            }

            self.tasksByVideoID[videoID] = task
            self.targetsByTask[task.taskIdentifier] = max(1, targetSeconds)
            self.bumpLRU(videoID)

            print("➡️ prefetch start videoID=\(videoID) target≈\(Int(targetSeconds))s")
            self.gate.wait()
            task.resume()
        }
    }

    func localAsset(for url: URL) -> AVURLAsset {
        // Создаём asset с такими же заголовками, чтобы runtime загрузки сегментов совпадал.
        AVURLAsset(url: url, options: [ "AVURLAssetHTTPHeaderFieldsKey": defaultHeaders ])
    }

    func prefetchedSeconds(for videoID: Int) -> Double {
        syncQ.sync { prefetchedByVideoID[videoID] ?? 0 }
    }

    func cachedVideoIDs() -> [Int] {
        syncQ.sync { prefetchedByVideoID.filter { $0.value > 0 }.map { $0.key } }
    }

    func cachedSummary() -> [Int: Double] {
        syncQ.sync { prefetchedByVideoID }
    }

    func isNotCacheable(videoID: Int) -> Bool {
        syncQ.sync { notCacheableIDs.contains(videoID) }
    }

    // MARK: - LRU helpers
    private func bumpLRU(_ videoID: Int) {
        if let idx = lruOrder.firstIndex(of: videoID) { lruOrder.remove(at: idx) }
        lruOrder.append(videoID)
    }

    private func enforceLRULimit() {
        while tasksByVideoID.count >= maxConcurrentDownloads, let old = lruOrder.first {
            print("🧹 cancel LRU prefetch videoID=\(old)")
            if let task = tasksByVideoID[old] { task.cancel() }
            tasksByVideoID.removeValue(forKey: old)
            lruOrder.removeFirst()
        }
    }
}

// MARK: - AVAssetDownloadDelegate
extension HLSDownloadManager: AVAssetDownloadDelegate {
    func urlSession(_ session: URLSession,
                    assetDownloadTask: AVAssetDownloadTask,
                    didLoad timeRange: CMTimeRange,
                    totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                    timeRangeExpectedToLoad: CMTimeRange) {

        let loadedSeconds = loadedTimeRanges
            .map { ($0 as! CMTimeRange).duration.seconds }
            .reduce(0, +)

        let expectedSeconds = timeRangeExpectedToLoad.duration.seconds.isFinite
            ? timeRangeExpectedToLoad.duration.seconds
            : .greatestFiniteMagnitude

        let target = targetsByTask[assetDownloadTask.taskIdentifier] ?? 0
        let effectiveTarget = min(target, expectedSeconds)

        if loadedSeconds >= effectiveTarget {
            syncQ.async {
                if let pair = self.tasksByVideoID.first(where: { $0.value.taskIdentifier == assetDownloadTask.taskIdentifier }) {
                    self.prefetchedByVideoID[pair.key] = min(loadedSeconds, effectiveTarget)
                    print("✅ prefetch done videoID=\(pair.key) ~\(Int(self.prefetchedByVideoID[pair.key]!))s")
                }
            }
            assetDownloadTask.cancel()
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        syncQ.async {
            defer { self.gate.signal() }

            if let (videoID, _) = self.tasksByVideoID.first(where: { $0.value.taskIdentifier == task.taskIdentifier }) {
                self.tasksByVideoID.removeValue(forKey: videoID)
                if let idx = self.lruOrder.firstIndex(of: videoID) { self.lruOrder.remove(at: idx) }

                if let err = error as NSError? {
                    let cmCode = err.code
                    let reason: String
                    switch cmCode {
                    case -17913: reason = "CMFormat/unsupported for offline (code -17913)"
                    case -1:     reason = "CMError unknown (-1) — часто HLS/headers mismatch"
                    default:     reason = "error \(cmCode)"
                    }
                    print("⚠️ prefetch error videoID=\(videoID): \(reason)")
                    // Если свалилось рано — больше не мучаем этот id
                    self.notCacheableIDs.insert(videoID)
                }
            }
            self.targetsByTask.removeValue(forKey: task.taskIdentifier)
        }
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error { print("❌ HLS session invalid: \(error.localizedDescription)") }
    }
}
