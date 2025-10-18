//
//  MainView.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//

import SwiftUI

struct MainView: View {
    @State private var firstItem: VideoRecommendation?
    @State private var isLoading = true
    @State private var showReels = false

    private let repo: VideoRepository = DefaultVideoRepository(client: DefaultHTTPClient())

    var body: some View {
        ZStack {
            
            LinearGradient(colors: [.black, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Главная")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Group {
                    if let item = firstItem, let urlStr = item.preview_image, let url = URL(string: urlStr) {
                        // карточка-превью
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img
                                    .resizable()
                                    .scaledToFill()
                            case .failure(_):
                                Color.gray.opacity(0.2)
                            case .empty:
                                Color.gray.opacity(0.2)
                            @unknown default:
                                Color.gray.opacity(0.2)
                            }
                        }
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                                startPoint: .center, endPoint: .bottom
                            )
                        )
                        .overlay(
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.title)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                Text("Открыть рилсы")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(.white.opacity(0.16), in: Capsule())
                            }
                            .padding(16),
                            alignment: .bottomLeading
                        )
                        .frame(height: 340)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                        .padding(.horizontal, 20)
                        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .onTapGesture {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                showReels = true
                            }
                        }
                        .accessibilityLabel("Открыть ленту рилсов")
                    } else {
                        
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 340)
                            .padding(.horizontal, 20)
                            .shimmer()
                    }
                }

                Spacer()
            }

            
            if showReels {
                ReelsView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .onDisappear {
                        
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            showReels = false
                        }
                    }
            }
        }
        .task {
            await loadPreview()
        }
    }

    private func loadPreview() async {
        guard isLoading else { return }
        isLoading = false
        do {
            let items = try await repo.fetchRecommendations(offset: 0, limit: 1)
            await MainActor.run {
                self.firstItem = items.first
            }
        } catch {
            await MainActor.run {
                self.firstItem = nil
            }
        }
    }
}


private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -0.6
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(gradient: Gradient(colors: [
                    .clear, .white.opacity(0.35), .clear
                ]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .rotationEffect(.degrees(25))
                .offset(x: phase * 300)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 0.8
                }
            }
    }
}
private extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
