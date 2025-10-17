import Foundation
import Combine
import AVFoundation

@MainActor
final class ReelsViewModel: ObservableObject {
    @Published var items: [VideoRecommendation] = []
    @Published var activeVideoID: Int?

    // общий плеер
    let player = AVPlayer()

    private let repo: VideoRepository = DefaultVideoRepository(client: DefaultHTTPClient())
    private var itemCancellables = Set<AnyCancellable>()
    private var timeObserver: Any?
    private var lastPlayedID: Int?

    deinit {
        if let obs = timeObserver { player.removeTimeObserver(obs) }
        NotificationCenter.default.removeObserver(self)
        itemCancellables.removeAll()
    }

    // Загружаем ленту
    func load() async {
        do {
            let recs = try await repo.fetchRecommendations(offset: 0, limit: 30)
            self.items = recs
            if let first = recs.first {
                setActive(videoID: first.video_id)
            }
        } catch {
            print("reels load error:", error)
        }
    }

    // Установка активного клипа
    func setActive(videoID: Int, mute: Bool = true) {
        guard activeVideoID != videoID else { return }
        activeVideoID = videoID
        play(videoID: videoID, mute: mute)
    }

    // Проиграть конкретный id в общем плеере (с автоплеем и репитом)
    func play(videoID: Int, mute: Bool = true) {
        guard lastPlayedID != videoID else { return }         // важное: не пересоздаём тот же item
        lastPlayedID = videoID

        let url   = InteresnoAPI.hlsPlaylistURL(videoID: videoID)
        let asset = AVURLAsset(url: url)
        let item  = AVPlayerItem(asset: asset)

        // буфер/битрейт
        player.automaticallyWaitsToMinimizeStalling = false
        item.preferredForwardBufferDuration = 0.8

        player.replaceCurrentItem(with: item)                 // старое видео автоматически останавливается
        player.currentItem?.preferredPeakBitRate = 1_200_000
        player.preventsDisplaySleepDuringVideoPlayback = true
        player.allowsExternalPlayback = false
        player.isMuted = mute

        // первая попытка — если рано, Combine добьёт
        player.playImmediately(atRate: 1.0)

        attachItemAutoplayObservers(for: item)
        attachDiagnosticsIfNeeded()
        attachLoop(for: item)
    }

    // Репит через seek к нулю
    private func attachLoop(for item: AVPlayerItem) {
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                    self.player.playImmediately(atRate: 1.0)
                }
            }
            .store(in: &itemCancellables)
    }

    // Автоплей — Combine вместо KVO
    private func attachItemAutoplayObservers(for item: AVPlayerItem) {
        itemCancellables.removeAll()

        item.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self else { return }
                if status == .readyToPlay {
                    self.player.playImmediately(atRate: 1.0)
                }
            }
            .store(in: &itemCancellables)

        item.publisher(for: \.isPlaybackLikelyToKeepUp)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] keepUp in
                guard let self, keepUp else { return }
                self.player.playImmediately(atRate: 1.0)
            }
            .store(in: &itemCancellables)

        NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled, object: item)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.player.playImmediately(atRate: 1.0)
            }
            .store(in: &itemCancellables)
    }

    // Диагностика (опционально)
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
            debugPrint(String(format: "reels ⏱ %.2f s, status=%@, reason=%@", t.seconds, status, reason))
        }
    }
}
