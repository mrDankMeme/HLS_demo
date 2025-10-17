//
//  ReelsView.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//

import SwiftUI
import AVFAudio
import AVFoundation

struct ReelsView: View {
    @StateObject private var vm: ReelsViewModel

    init() {
        let http = DefaultHTTPClient()
        let repo = DefaultVideoRepository(client: http)
        _vm = StateObject(wrappedValue: ReelsViewModel(repo: repo))
    }

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
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("AudioSession error:", error)
            }
            await vm.load()
        }
        .onDisappear { vm.player.pause() }
        .navigationTitle("Reels")
    }
}
