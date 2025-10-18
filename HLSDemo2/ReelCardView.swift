//
//  ReelCardView.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/18/25.
//

import SwiftUI
import AVKit

struct ReelCardView: View {
    let index: Int
    let isActive: Bool
    let title: String
    let previewURL: URL?
    let player: AVPlayer

    private let username = "@kristina"
    private let tags = ["#португалия", "#природа", "#лето", "#океан", "#пляж", "#волны", "#закат", "#море", "#релакс", "#trip", "#sunset"]
    @State private var liked = false

    var body: some View {
        GeometryReader { geo in
            let cardSize = geo.size

            ZStack {
                // 1) Бэкграунд фиксированного размера — базовая геометрия карточки
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black)
                    .frame(width: cardSize.width, height: cardSize.height)

                // 2) ВСЕГДА рендерим плеер (одинаковое дерево вида → стабильный layout)
                PlayerLayerView(player: player)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .allowsHitTesting(false)

                // 3) Превью-картинка ЛЕЖИТ СВЕРХУ и просто скрывается, когда ролик активен
                previewLayer(size: cardSize)
                    .opacity(isActive ? 0.0 : 1.0)
                    .animation(.easeOut(duration: 0.18), value: isActive)
                    .allowsHitTesting(false)

                // 4) Стабильные слои поверх — градиенты и контент
                gradientsOverlay
                    .frame(width: cardSize.width, height: cardSize.height)
                    .allowsHitTesting(false)

                contentOverlay
                    .frame(width: cardSize.width, height: cardSize.height)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - Preview layer (одинаковая геометрия для активного/неактивного)
    private func previewLayer(size: CGSize) -> some View {
        Group {
            if let url = previewURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .empty: Rectangle().fill(Color.black.opacity(0.2))
                    case .failure: Rectangle().fill(Color.black.opacity(0.3))
                    @unknown default: Rectangle().fill(Color.black.opacity(0.3))
                    }
                }
            } else {
                Rectangle().fill(Color.black.opacity(0.25))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Градиенты поверх
    private var gradientsOverlay: some View {
        VStack {
            LinearGradient(colors: [Color.black.opacity(0.45), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 190)
                .frame(maxWidth: .infinity)
            Spacer()
            LinearGradient(colors: [.clear, Color.black.opacity(0.55)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 230)
                .frame(maxWidth: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Контент (не зависит от видео/превью)
    private var contentOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Верх
            HStack(alignment: .top, spacing: 16) {
                avatarBlock
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(username)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color(red: 0.27, green: 0.56, blue: 1.0))
                            .font(.system(size: 20))
                    }
                    Text(title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .shadow(color: .black.opacity(0.6), radius: 3)
                }
                Spacer()
            }
            .padding(.top, 18)
            .padding(.horizontal, 18)

            Spacer()

            // Хэштеги
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(tags, id: \.self) { t in
                        Text(t)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 44)
            .padding(.bottom, 10)

            // Нижняя панель
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(.white)
                    Text("Россия, Сочи")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye").foregroundStyle(.white)
                        Text("567")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { liked.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: liked ? "heart.fill" : "heart")
                                .foregroundStyle(liked ? .pink : .white)
                                .scaleEffect(liked ? 1.15 : 1.0)
                            Text("1.5k")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Аватар

    private var avatarBlock: some View {
        ZStack(alignment: .bottom) {
            // 🟦 Внешняя рамка + фон
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.95), lineWidth: 4)
                .background(
                    // Внутренний контент (аватар или плейсхолдер)
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .overlay(
                            // 👉 сюда добавляем аватар
                            avatarImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 116, height: 152)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        )
                )
                .frame(width: 116, height: 152)

            // 🟥 Метка Live
            Text("Live")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(red: 1.00, green: 0.30, blue: 0.22))
                .clipShape(Capsule())
                .offset(y: 10)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Изображение для аватара
    private var avatarImage: Image {
        // Можно заменить на AsyncImage(url:) если аватар приходит по URL
        Image("avatar_sample") // 🔹 добавь картинку в Assets.xcassets
    }

}
