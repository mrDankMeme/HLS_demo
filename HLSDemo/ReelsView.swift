import SwiftUI
import AVFAudio

struct ReelsView: View {
    @StateObject private var vm = ReelsViewModel()

    var body: some View {
        ReelsPagerRepresentable(
            items: vm.items,
            activeID: vm.activeVideoID,
            player: vm.player,
            onActiveIndexChanged: { index in
                guard index >= 0, index < vm.items.count else { return }
                vm.setActive(videoID: vm.items[index].video_id, mute: true)
            }
        )
        .ignoresSafeArea()
        .task {
            configureAudioSessionForPlayback()
            await vm.load()
        }
        .navigationTitle("Reels")
    }
}
