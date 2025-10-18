//
//  HLSSegmentPrefetcher.swift
//  HLSDemo2
//
//  Updated by Niiaz Khasanov on 10/18/25
//

import Foundation

/// Префетчит N секунд: берём низкий битрейт в мастере, скачиваем сегменты последовательно.
/// Дружелюбен к воспроизведению: низкий приоритет, 1 соединение, пауза при буферных проблемах.
final class HLSSegmentPrefetcher {
    static let shared = HLSSegmentPrefetcher()

    private let store = HLSSegmentStore.shared

    // Сетевой стек
    private let q   = DispatchQueue(label: "hls.prefetcher", qos: .utility)
    private let sem = DispatchSemaphore(value: 1) // один активный плейлист
    private let session: URLSession

    // Учёт фоновых задач (для cancelAll)
    private var tasks: [URL: URLSessionDataTask] = [:]
    private var suspended = false

    private init() {
        let cfg = URLSessionConfiguration.ephemeral  // без системного дискового кеша, чтобы не конкурировать
        cfg.httpMaximumConnectionsPerHost = 1        // не мешаем плееру
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest  = 20
        cfg.timeoutIntervalForResource = 60
        cfg.httpAdditionalHeaders = [
            "User-Agent": "HLSDemo2/1.0 (iOS)",
            "Accept": "application/vnd.apple.mpegurl, application/x-mpegURL, */*"
        ]
        session = URLSession(configuration: cfg)
    }

    // MARK: Controls

    func suspend() {
        q.async {
            guard !self.suspended else { return }
            self.suspended = true
            self.tasks.values.forEach { $0.suspend() }
            print("⏸ prefetch SUSPEND")
        }
    }

    func resume() {
        q.async {
            guard self.suspended else { return }
            self.suspended = false
            self.tasks.values.forEach { $0.resume() }
            print("▶️ prefetch RESUME")
        }
    }

    /// Отменить все фоновые префетчи (полезно при смене активного видео).
    func cancelAll() {
        q.async {
            self.tasks.values.forEach { $0.cancel() }
            self.tasks.removeAll()
            print("⛔️ prefetch CANCEL ALL")
        }
    }

    /// Префетчим первые seconds с небольшой задержкой (по умолчанию 0.7s), чтобы плеер успел забрать первый сегмент.
    func prefetchFirstSeconds(from playlistURL: URL, seconds: Double, delay: TimeInterval = 0.7) {
        q.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            if self.suspended { return } // не стартуем, если сейчас пауза
            self.sem.wait()
            self.fetchWithRetry(url: playlistURL, retries: 2) { [weak self] data in
                guard let self else { return }
                defer { self.sem.signal() }

                guard let data else { return }
                let (kind, segments, variants) = HLSPlaylistParser.parse(baseURL: playlistURL, data: data)

                switch kind {
                case .master:
                    guard let best = variants.min(by: { $0.bandwidth < $1.bandwidth }) else { return }
                    print("🎛 master -> pick LOWEST bitrate: \(best.bandwidth == .max ? -1 : best.bandwidth) → \(best.url.lastPathComponent)")
                    self.prefetchFirstSeconds(from: best.url, seconds: seconds, delay: 0)

                case .media:
                    var sum = 0.0
                    for seg in segments {
                        if sum >= seconds || self.suspended { break }
                        if !self.store.has(seg.url) {
                            self.fetchWithRetry(url: seg.url, retries: 2) { [weak self] data in
                                guard let self, let data else { return }
                                self.store.write(data, for: seg.url)
                                print("⬇️ cached segment: \(seg.url.lastPathComponent) (\(Int(seg.duration))s)")
                            }
                        } else {
                            print("✅ segment hit (already cached): \(seg.url.lastPathComponent)")
                        }
                        sum += seg.duration
                    }
                }
            }
        }
    }

    // MARK: - Networking with retry

    private func fetchWithRetry(url: URL, retries: Int, completion: @escaping (Data?) -> Void) {
        var attempt = 0

        func run() {
            var req  = URLRequest(url: url)
            req.allowsExpensiveNetworkAccess = true
            req.networkServiceType = .background  // iOS старается не мешать интерактиву
            let task = session.dataTask(with: req) { [weak self] data, _, err in
                // удалить запись о задаче
                self?.q.async { self?.tasks.removeValue(forKey: url) }

                if let err = err as? URLError, err.code == .timedOut, attempt < retries {
                    attempt += 1
                    let backoff = pow(2.0, Double(attempt)) // 2s, 4s...
                    print("🔁 retry \(attempt) for \(url.lastPathComponent) in \(Int(backoff))s (timeout)")
                    guard let strongSelf = self else { return }
                    strongSelf.q.asyncAfter(deadline: .now() + backoff) { run() }
                    return
                }

                if let err = err {
                    print("❌ fetch error \(url.lastPathComponent): \(err.localizedDescription)")
                }
                completion(data)
            }

            task.priority = URLSessionTask.lowPriority    // самый низкий приоритет
            q.async { [weak self] in self?.tasks[url] = task }
            if suspended { task.suspend() }
            task.resume()
        }

        run()
    }
}
