import SwiftUI
import AVFoundation

struct SingleVideoView: View {
    @StateObject private var vm = SingleVideoViewModel()
    /// nil → автоматически найдём первый полностью открытый ролик
    let videoID: Int?

    var body: some View {
        VStack {
            PlayerViewRepresentable(player: vm.player, showsControls: true, fill: true)
                .task {
                    configureAudioSessionForPlayback()
                    if let id = videoID {
                        vm.loadAndPlay(videoID: id, mute: true)
                    } else {
                        await vm.loadFirstFreeAndPlay(mute: true)
                    }
                }

            HStack {
                Button(vm.isPlaying ? "Pause" : "Play") {
                    if vm.isPlaying {
                        vm.pause()
                    } else {
                        vm.player.playImmediately(atRate: 1.0)
                        vm.isPlaying = true
                    }
                }
                .buttonStyle(.bordered)

                Button(vm.player.isMuted ? "Unmute" : "Mute") {
                    vm.player.isMuted.toggle()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle(videoID != nil ? "HLS #\(videoID!)" : "HLS (first free)")
    }
}
