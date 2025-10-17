//
//  ReelDistanceKey.swift
//  HLSDemo
//
//  Created by Niiaz Khasanov on 10/17/25.
//


import SwiftUI

// PreferenceKey для передачи расстояния карточек до центра экрана
private struct ReelDistanceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int : CGFloat], nextValue: () -> [Int : CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
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
                let id = vm.items[index].video_id
                vm.setActive(videoID: id, mute: true)   // сразу переключаем плеер
            }
        )
        .ignoresSafeArea()
        .background(Color.black)
        .task {
            configureAudioSessionForPlayback()
            await vm.load()
        }
        .navigationTitle("Reels")
    }
}


