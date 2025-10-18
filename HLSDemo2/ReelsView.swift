//
//  ReelsView.swift
//  HLSDemo2
//
//  Пейджинг без «сползания»: страница = карточка + 20pt, карточка по центру.
//  Автоплей стартует через 2 сек. после приземления страницы.
//  iOS 17+
//

import SwiftUI
import AVKit
import AVFoundation

struct ReelsView: View {
    @StateObject private var vm: ReelsViewModel

    // Настройки
    private let heightRatio: CGFloat = 0.65
    private let hPad: CGFloat = 34
    private let interItemGap: CGFloat = 20   // расстояние между карточками

    // Текущая страница
    @State private var scrollID: Int? = 0
    @State private var didSetInitial = false

    // Таймер отложенной активации
    @State private var pendingActivation: Task<Void, Never>? = nil
    private let autoplayDelay: Duration = .seconds(1)

    init() {
        let http = DefaultHTTPClient()
        let repo = DefaultVideoRepository(client: http)
        _vm = StateObject(wrappedValue: ReelsViewModel(repo: repo))
    }

    var body: some View {
        GeometryReader { proxy in
            let screenH = proxy.size.height
            let cardH   = floor(screenH * heightRatio)
            let pageH   = cardH + interItemGap
            let margins = max(0, (screenH - pageH) / 2)

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(0..<vm.items.count, id: \.self) { idx in
                        let m = vm.items[idx]
                        let active = (vm.activeVideoID == m.video_id)
                        let preview: URL? = m.preview_image.flatMap { URL(string: $0) }

                        ZStack {
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

            // ❗️Отложенная активация плеера после приземления страницы
            .onChange(of: scrollID) { _, new in
                guard let new, new >= 0, new < vm.items.count else { return }

                // Ставим на паузу текущий плеер и отменяем прошлую задачу
                vm.player.pause()
                pendingActivation?.cancel()

                // Планируем автоплей через 2 секунды
                pendingActivation = Task { @MainActor in
                    try? await Task.sleep(for: autoplayDelay)
                    // если пользователь не перелистнул ещё раз — активируем
                    if new == scrollID {
                        vm.setActive(videoID: vm.items[new].video_id, mute: true)
                    }
                }
            }

            // начальная позиция — после первой раскладки
            .onChange(of: vm.items.count) { _, count in
                guard count > 0, !didSetInitial else { return }
                DispatchQueue.main.async {
                    didSetInitial = true
                    scrollID = 0
                    // стартуем тоже с задержкой через onChange(scrollID)
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
            vm.player.pause()
        }
        .navigationTitle("Reels")
        .animation(.easeOut(duration: 0.22), value: scrollID)
    }

    private func setupAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioSession error:", error)
        }
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
