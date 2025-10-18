//
//  ReelsViewModel.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
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

    private let lastIDKey = "reels.lastActiveVideoID"

    init(repo: VideoRepository, player: AVPlayer = AVPlayer()) {
        self.repo = repo
        self.player = player
        bindAppLifecycle()
        attachDiagnosticsIfNeeded()
        if let saved = readLastID() { activeVideoID = saved }
    }

    deinit {
        if let obs = timeObserver { player.removeTimeObserver(obs) }
        NotificationCenter.default.removeObserver(self)
        lifetimeCancellables.removeAll()
        itemCancellables.removeAll()
    }

    func load() async {
        do {
            let recs = try await repo.fetchRecommendations(offset: 0, limit: 40)
            let playable = recs.filter { ($0.has_access ?? false) || (($0.free ?? false) && $0.time_not_reg == nil) }
            self.items = playable

            let preferredID: Int? = {
                if let saved = readLastID(),
                   playable.contains(where: { $0.video_id == saved }) { return saved }
                return playable.first?.video_id
            }()

            if let id = preferredID {
                setActive(videoID: id)
            }
        } catch {
            print("reels load error:", error)
        }
    }

    func setActive(videoID: Int, mute: Bool = true) {
        guard activeVideoID != videoID else { return }

        prepareAndAutoplay(videoID: videoID, mute: mute)
        activeVideoID = videoID
        writeLastID(videoID)

        if let idx = items.firstIndex(where: { $0.video_id == videoID }) {
            preheater.warmNeighbors(currentIndex: idx, items: items)
        }
    }

    private func prepareAndAutoplay(videoID: Int, mute: Bool) {
        guard lastLoadedID != videoID else { return }
        lastLoadedID = videoID

        let asset = preheater.asset(for: videoID)
        let item  = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 2.5

        player.pause()
        player.automaticallyWaitsToMinimizeStalling = true
        player.replaceCurrentItem(with: item)
        player.preventsDisplaySleepDuringVideoPlayback = true
        player.allowsExternalPlayback = false
        player.isMuted = mute

        attachObservers(for: item)
        attachLoop(for: item)

        startPlaybackIfNeeded()
        kickstartIfNoProgress()
    }

    private func attachLoop(for item: AVPlayerItem) {
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                    self.startPlaybackIfNeeded()
                }
            }
            .store(in: &itemCancellables)
    }

    private func attachObservers(for: AVPlayerItem) {
        itemCancellables.removeAll()

        player.publisher(for: \.timeControlStatus)
            .removeDuplicates()
            .sink { _ in }
            .store(in: &itemCancellables)
    }

    private func startPlaybackIfNeeded() {
        if player.timeControlStatus != .playing {
            player.play()
        }
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
            .sink { [weak self] _ in self?.player.pause() }
            .store(in: &lifetimeCancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.startPlaybackIfNeeded() }
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
            print(String(format: "reels %.2f s | %@", t.seconds, st))
        }
    }

    private func readLastID() -> Int? {
        UserDefaults.standard.object(forKey: lastIDKey) as? Int
    }

    private func writeLastID(_ id: Int) {
        UserDefaults.standard.set(id, forKey: lastIDKey)
    }
}
