//
//  ReelsViewModel.swift
//  HLSDemo2
//
//  Updated by Niiaz Khasanov on 10/18/25
//

import Foundation
import Combine
import AVFoundation
import UIKit

@MainActor
final class ReelsViewModel: ObservableObject {
    @Published var items: [VideoRecommendation] = []
    @Published var activeVideoID: Int?

    let player: AVPlayer

    private let repo: VideoRepository
    private let preheater = ReelsPreheater()

    private var lifetimeCancellables = Set<AnyCancellable>()
    private var itemCancellables = Set<AnyCancellable>()
    private var timeObserver: Any?
    private var lastLoadedID: Int?

    init(repo: VideoRepository, player: AVPlayer = AVPlayer()) {
        self.repo = repo
        self.player = player
        bindAppLifecycle()
        attachDiagnosticsIfNeeded()
    }

    deinit {
        if let obs = timeObserver { player.removeTimeObserver(obs) }
        NotificationCenter.default.removeObserver(self)
    }

    func load() async {
        do {
            let recs = try await repo.fetchRecommendations(offset: 0, limit: 40)
            let playable = recs.filter { ($0.has_access ?? false) || (($0.free ?? false) && $0.time_not_reg == nil) }
            self.items = playable

            let files = HLSSegmentStore.shared.cachedSummary()
            if files.isEmpty { print("📭 HLS disk cache is empty") }
            else { print("📦 HLS disk cache files: \(files.count)") }

            if let first = playable.first { setActive(videoID: first.video_id) }
        } catch {
            print("reels load error:", error)
        }
    }

    func setActive(videoID: Int, mute: Bool = true) {
        guard activeVideoID != videoID else { return }
        print("🎬 activate videoID=\(videoID)")

        // 💡 Сначала гасим старые префетчи — уменьшаем конкуренцию
        HLSSegmentPrefetcher.shared.cancelAll()
        HLSSegmentPrefetcher.shared.resume() // гарантируем незапаузенное состояние для нового старта

        // потом префетчим текущий (60s) c небольшой задержкой
        preheater.prefetchCurrent(videoID: videoID)

        prepareAndAutoplay(videoID: videoID, mute: mute)
        activeVideoID = videoID

        if let idx = items.firstIndex(where: { $0.video_id == videoID }) {
            // соседей начнём тоже с задержкой внутри prefetcher
            preheater.warmNeighbors(currentIndex: idx, items: items)
        }
    }

    private func prepareAndAutoplay(videoID: Int, mute: Bool) {
        guard lastLoadedID != videoID else { return }
        lastLoadedID = videoID

        let asset = preheater.asset(for: videoID)
        let item  = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 4.0
        item.preferredPeakBitRate = 1_000_000

        print("▶️ start (cache will be logged per segment)")

        player.pause()
        player.automaticallyWaitsToMinimizeStalling = true
        player.replaceCurrentItem(with: item)
        player.preventsDisplaySleepDuringVideoPlayback = true
        player.allowsExternalPlayback = false
        player.isMuted = mute

        attachObservers(for: item)
        attachLoop(for: item)

        if player.timeControlStatus != .playing { player.play() }
        kickstartIfNoProgress()
    }

    private func attachLoop(for item: AVPlayerItem) {
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                    if self.player.timeControlStatus != .playing { self.player.play() }
                }
            }
            .store(in: &itemCancellables)
    }

    private func attachObservers(for item: AVPlayerItem) {
        itemCancellables.removeAll()

        // 👉 Когда плеер «голодает» — ставим префетчер на паузу. Когда норм — резюмим.
        player.publisher(for: \.timeControlStatus)
            .removeDuplicates()
            .sink { status in
                switch status {
                case .waitingToPlayAtSpecifiedRate, .paused:
                    HLSSegmentPrefetcher.shared.suspend()
                case .playing:
                    HLSSegmentPrefetcher.shared.resume()
                @unknown default:
                    break
                }
            }
            .store(in: &itemCancellables)
    }

    private func kickstartIfNoProgress() {
        Just(())
            .delay(for: .seconds(1.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.player.timeControlStatus != .playing {
                    self.player.play()
                }
            }
            .store(in: &itemCancellables)
    }

    private func bindAppLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.player.pause()
                HLSSegmentPrefetcher.shared.suspend()
            }
            .store(in: &lifetimeCancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in HLSSegmentPrefetcher.shared.resume() }
            .store(in: &lifetimeCancellables)
    }

    private func attachDiagnosticsIfNeeded() {
        guard timeObserver == nil else { return }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] t in
            guard let self else { return }
            let st: String = {
                switch self.player.timeControlStatus {
                case .paused: return "paused"
                case .waitingToPlayAtSpecifiedRate: return "waiting(\(self.player.reasonForWaitingToPlay?.rawValue ?? "nil"))"
                case .playing: return "playing"
                @unknown default: return "unknown"
                }
            }()
            print(String(format: "reels ⏱ %.2f s | %@", t.seconds, st))
        }
    }
}
