import Foundation
import Combine
import AVFoundation

@MainActor
final class SingleVideoViewModel: ObservableObject {
    @Published var isPlaying = false
    let player = AVPlayer()

    private let repo: VideoRepository = DefaultVideoRepository(client: DefaultHTTPClient())

    private var itemCancellables = Set<AnyCancellable>()
    private var timeObserver: Any?
    private var userPaused = false          // чтобы не ломать осознанную паузу пользователя

    deinit {
        if let obs = timeObserver { player.removeTimeObserver(obs) }
        NotificationCenter.default.removeObserver(self)
        itemCancellables.removeAll()
    }

    // MARK: - Public

    func loadAndPlay(videoID: Int, mute: Bool = true) {
        userPaused = false

        let url   = InteresnoAPI.hlsPlaylistURL(videoID: videoID)
        let asset = AVURLAsset(url: url)
        let item  = AVPlayerItem(asset: asset)

        // Анти-столлы/буфер/битрейт
        player.automaticallyWaitsToMinimizeStalling = false
        item.preferredForwardBufferDuration = 0.8
        player.replaceCurrentItem(with: item)
        player.currentItem?.preferredPeakBitRate = 1_200_000
        player.preventsDisplaySleepDuringVideoPlayback = true
        player.allowsExternalPlayback = false
        player.isMuted = mute

        // Первая попытка — если рано, Combine добьёт.
        player.playImmediately(atRate: 1.0)
        isPlaying = true

        attachItemObservers(for: item)
        attachDiagnosticsIfNeeded()
    }

    func loadFirstFreeAndPlay(mute: Bool = true) async {
        do {
            let items = try await repo.fetchRecommendations(offset: 0, limit: 20)
            if let v = items.first(where: { ($0.free ?? false) && $0.time_not_reg == nil }) {
                loadAndPlay(videoID: v.video_id, mute: mute)
            } else if let any = items.first {
                loadAndPlay(videoID: any.video_id, mute: mute)
            }
        } catch {
            debugPrint("fetch recommendations error:", error.localizedDescription)
        }
    }

    func pause() {
        userPaused = true
        player.pause()
        isPlaying = false
    }

    // MARK: - Private

    private func attachItemObservers(for item: AVPlayerItem) {
        itemCancellables.removeAll()

        // Автоплей когда готов
        item.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self else { return }
                if status == .readyToPlay, !self.userPaused {
                    self.player.playImmediately(atRate: 1.0)
                    self.isPlaying = true
                }
            }
            .store(in: &itemCancellables)

        // Автоплей когда буфер «держит»
        item.publisher(for: \.isPlaybackLikelyToKeepUp)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] keepUp in
                guard let self, keepUp, !self.userPaused else { return }
                self.player.playImmediately(atRate: 1.0)
                self.isPlaying = true
            }
            .store(in: &itemCancellables)

        // Репит: когда дошли до конца — перематываем к началу и сразу play
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard !self.userPaused else { return }          // пользователь на паузе — не автозапускаем
                let zero = CMTime.zero
                self.player.seek(to: zero, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                    self.player.playImmediately(atRate: 1.0)
                    self.isPlaying = true
                }
            }
            .store(in: &itemCancellables)

        // На случай внешних стопов
        NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled, object: item)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, !self.userPaused else { return }
                self.player.playImmediately(atRate: 1.0)
                self.isPlaying = true
            }
            .store(in: &itemCancellables)
    }

    private func attachDiagnosticsIfNeeded() {
        guard timeObserver == nil else { return }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] t in
            guard let self else { return }
            let status: String
            switch self.player.timeControlStatus {
            case .paused: status = "paused"
            case .waitingToPlayAtSpecifiedRate: status = "waiting"
            case .playing: status = "playing"
            @unknown default: status = "unknown"
            }
            let reason = self.player.reasonForWaitingToPlay?.rawValue ?? "nil"
            debugPrint(String(format: "⏱ %.2f s, status=%@, reason=%@", t.seconds, status, reason))
        }
    }
}
