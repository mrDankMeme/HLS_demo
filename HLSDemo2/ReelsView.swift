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
    private let heightRatio: CGFloat = 0.8
    private let hPad: CGFloat = 34
    private let interItemGap: CGFloat = 20

    // Пейджинг/позиция
    @State private var scrollID: Int? = 0
    @State private var didSetInitial = false
    @State private var pendingActivation: Task<Void, Never>? = nil
    private let autoplayDelay: Duration = .seconds(1)

    // Один раз инициализируем (чтобы .task не запускался повторно после возврата)
    @State private var didBootstrap = false

    // ⚠️ флаг, чтобы не останавливать плеер при переходе на деталку
    @State private var isShowingDetail = false

    init() {
        let http = DefaultHTTPClient()
        let repo = DefaultVideoRepository(client: http)
        _vm = StateObject(wrappedValue: ReelsViewModel(repo: repo))
    }

    var body: some View {
        NavigationStack {
            ZStack {
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
                        .padding(.top, 0)
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

                    // первая и только первая загрузка
                    .task {
                        guard !didBootstrap else { return }
                        didBootstrap = true
                        setupAudio()
                        await vm.load()
                        if !vm.items.isEmpty {
                            didSetInitial = true
                            if let id = vm.activeVideoID,
                               let idx = vm.items.firstIndex(where: { $0.video_id == id }) {
                                scrollID = idx
                            } else {
                                scrollID = 0
                            }
                        }
                    }

                    // при возврате с деталки — убеждаемся, что стоим на активном индексе
                    .onAppear {
                        if let id = vm.activeVideoID,
                           let idx = vm.items.firstIndex(where: { $0.video_id == id }) {
                            if scrollID != idx {
                                scrollID = idx
                            }
                        }
                    }
                }

                // 🔻 Плавающая нижняя панель
                BottomDock(
                    onHome: { /* TODO */ },
                    onBell: { /* TODO */ },
                    onPlus: { /* TODO */ },
                    onChat: { /* TODO */ },
                    onProfile: { /* TODO */ }
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .zIndex(50)
                // чтобы скролл проходил под панелью и её не дёргал
                .allowsHitTesting(true)
            }
            .onDisappear {
                pendingActivation?.cancel()
                if !isShowingDetail { vm.player.pause() }
            }

            // прячем системный навбар
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarHidden(true)
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
            .scaleEffect(1.0)
            .opacity(1.0)
            .shadow(color: .black.opacity(isActive ? 0.35 : 0.0),
                    radius: isActive ? 18 : 0, x: 0, y: 12)
    }
}

// MARK: - Bottom Dock

private struct BottomDock: View {
    var onHome: () -> Void
    var onBell: () -> Void
    var onPlus: () -> Void
    var onChat: () -> Void
    var onProfile: () -> Void

    var body: some View {
        HStack(spacing: 28) {
            iconButton(system: "house.fill", action: onHome)

            iconButton(system: "bell.fill", action: onBell)

            // большой плюс по центру
            Button(action: onPlus) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 54, height: 54)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                }
            }
            .buttonStyle(.plain)

            iconButton(system: "ellipsis.bubble.fill", action: onChat)

            // аватар справа
            Button(action: onProfile) {
                Image("avatar_sample") // добавь в Assets, иначе заменяй на system
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.85),
                    Color.black.opacity(0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .background(.ultraThinMaterial)
        )
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
    }

    private func iconButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
    }
}
