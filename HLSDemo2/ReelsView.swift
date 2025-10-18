//
//  ReelsView.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//

import SwiftUI
import AVKit
import AVFoundation

struct ReelsView: View {
    @StateObject private var vm: ReelsViewModel

    // Геометрия карточек
    private let heightRatio: CGFloat = 0.65
    private let hPad: CGFloat = 34
    private let interItemGap: CGFloat = 20

    // Пейджинг
    @State private var scrollID: Int? = 0
    @State private var didSetInitial = false
    @State private var pendingActivation: Task<Void, Never>? = nil
    private let autoplayDelay: Duration = .seconds(1)

    // ⚠️ флаг, чтобы не останавливать плеер при переходе на деталку
    @State private var isShowingDetail = false

    init() {
        let http = DefaultHTTPClient()
        let repo = DefaultVideoRepository(client: http)
        _vm = StateObject(wrappedValue: ReelsViewModel(repo: repo))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let screenH = proxy.size.height
                let cardH   = floor(screenH * heightRatio)
                let pageH   = cardH + interItemGap
                let margins = max(0, (screenH - pageH) / 2)

                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(vm.items.enumerated()), id: \.element.id) { idx, m in
                            let active = (vm.activeVideoID == m.video_id)
                            let preview = m.preview_image.flatMap(URL.init(string:))

                            // навигация в деталку: выставляем флаг, чтобы не паузить плеер
                            NavigationLink {
                                ReelDetailView(video: m, sharedPlayer: vm.player)
                                    .onAppear { isShowingDetail = true }
                                    .onDisappear { isShowingDetail = false }
                            } label: {
                                ReelCardView(
                                    index: idx,
                                    isActive: active,
                                    title: m.title,
                                    previewURL: preview,
                                    player: vm.player
                                )
                                .frame(height: cardH)
                                .padding(.horizontal, hPad)
                                .modifier(ActiveHighlight(isActive: active))
                            }
                            .buttonStyle(.plain)
                            .frame(height: pageH)
                            .id(idx)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrollID, anchor: .center)
                .contentMargins(.vertical, margins, for: .scrollContent)
                .background(Color.black.ignoresSafeArea())

                // отложенная активация нового видео после скролла
                .onChange(of: scrollID) { _, new in
                    guard let new, new >= 0, new < vm.items.count else { return }
                    vm.player.pause()
                    pendingActivation?.cancel()
                    pendingActivation = Task { @MainActor in
                        try? await Task.sleep(for: autoplayDelay)
                        if new == scrollID {
                            vm.setActive(videoID: vm.items[new].video_id, mute: true)
                        }
                    }
                }

                // первая загрузка
                .onChange(of: vm.items.count) { _, count in
                    guard count > 0, !didSetInitial else { return }
                    DispatchQueue.main.async {
                        didSetInitial = true
                        scrollID = 0
                    }
                }
                .task {
                    setupAudio()
                    await vm.load()
                    if !vm.items.isEmpty {
                        DispatchQueue.main.async {
                            didSetInitial = true
                            scrollID = 0
                        }
                    }
                }
            }
            .onDisappear {
                pendingActivation?.cancel()
                // ❗️не останавливаем плеер, если мы просто ушли на экран деталки
                if !isShowingDetail {
                    vm.player.pause()
                }
            }
            .navigationTitle("Reels")
            .animation(.easeOut(duration: 0.22), value: scrollID)
        }
    }

    private func setupAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("AudioSession error:", error) }
    }
}

// Подсветка активной карточки
private struct ActiveHighlight: ViewModifier {
    let isActive: Bool
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 1.0 : 0.94)
            .opacity(isActive ? 1.0 : 0.6)
            .shadow(color: .black.opacity(isActive ? 0.35 : 0.0),
                    radius: isActive ? 18 : 0, x: 0, y: 12)
    }
}
