import SwiftUI
import AVFAudio
import AVFoundation

struct ReelsView: View {
    @StateObject private var vm: ReelsViewModel

    @State private var showDetail = false
    @State private var didConfigureFirstActivation = false

    init() {
        let http = DefaultHTTPClient()
        let repo = DefaultVideoRepository(client: http)
        _vm = StateObject(wrappedValue: ReelsViewModel(repo: repo))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ReelsPagerRepresentable(
                    items: vm.items,
                    activeID: vm.activeVideoID,
                    player: vm.player,
                    isShowingDetail: showDetail,
                    onActiveIndexChanged: { index in
                        guard index >= 0, index < vm.items.count else { return }
                        if !didConfigureFirstActivation {
                            // первый запуск — всегда без звука
                            vm.setActive(videoID: vm.items[index].video_id, mute: true)
                            didConfigureFirstActivation = true
                        } else {
                            // в списке держим mute = true
                            vm.setActive(videoID: vm.items[index].video_id, mute: true)
                        }
                    },
                    onTapActive: {
                        // просто открываем деталку (звук включится там)
                        showDetail = true
                    }
                )
                .ignoresSafeArea()
            }
            .navigationDestination(isPresented: $showDetail) {
                ReelsDetailView(player: vm.player) {
                    showDetail = false
                }
                .ignoresSafeArea()
            }
            .task {
                do {
                    try AVAudioSession.sharedInstance().setCategory(
                        .playback, mode: .moviePlayback, options: [.mixWithOthers]
                    )
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    print("AudioSession error:", error)
                }
                // грузим и стартуем автоплей (плеер будет в mute)
                await vm.load()
                vm.player.isMuted = true
                if vm.player.timeControlStatus != .playing {
                    vm.player.play()
                }
            }
            // каждый раз, когда экран списка появляется — принудительно mute
            .onAppear {
                vm.player.isMuted = true
            }
            // при уходе с экрана списка (в т.ч. назад на главный):
            // останавливаем, мьютим и сбрасываем item, чтобы звук НИКОГДА не тянулся
            .onDisappear {
                vm.player.isMuted = true
                vm.player.pause()
                vm.player.replaceCurrentItem(with: nil)
            }
            // возврат с деталки в список — снова mute и продолжаем проигрывать без звука
            .onChange(of: showDetail) { isShown in
                if !isShown {
                    vm.player.isMuted = true
                    if vm.player.timeControlStatus != .playing {
                        vm.player.play()
                    }
                }
            }
            .navigationTitle("Reels")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
