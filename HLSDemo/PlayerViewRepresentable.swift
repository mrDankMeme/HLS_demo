import SwiftUI
import AVKit
import AVFAudio

final class AutoplayPlayerViewController: AVPlayerViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // На экране? Ещё раз дожмём автоплей.
        player?.playImmediately(atRate: 1.0)
    }
}

struct PlayerViewRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    var showsControls: Bool = true
    var fill: Bool = true

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AutoplayPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = showsControls
        vc.videoGravity = fill ? .resizeAspectFill : .resizeAspect
        vc.allowsPictureInPicturePlayback = true
        vc.canStartPictureInPictureAutomaticallyFromInline = true
        vc.updatesNowPlayingInfoCenter = false
        return vc
    }

    func updateUIViewController(_ ui: AVPlayerViewController, context: Context) {
        if ui.player !== player { ui.player = player }
    }
}

func configureAudioSessionForPlayback() {
    do {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try AVAudioSession.sharedInstance().setActive(true)
    } catch {
        print("AudioSession error:", error)
    }
}
