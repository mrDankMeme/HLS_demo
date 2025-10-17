//
//  ReelCardView.swift
//  HLSDemo
//
//  Created by Niiaz Khasanov on 10/17/25.
//


import SwiftUI
import AVFoundation

/// Одна карточка «рила». Если активна — показывает общий плеер; иначе — превью-картинку.
struct ReelCardView: View {
    let item: VideoRecommendation
    let isActive: Bool
    let player: AVPlayer

    var body: some View {
        ZStack {
            if isActive {
                PlayerViewRepresentable(player: player, showsControls: true, fill: true)
                    .id("player-\(item.video_id)") // стабильность обновлений
            } else {
                if let urlStr = item.preview_image, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure(_):
                            placeholder
                        case .empty:
                            Color.black.opacity(0.6)
                        @unknown default:
                            Color.black.opacity(0.6)
                        }
                    }
                } else {
                    placeholder
                }
            }

            // заголовок/оверлей
            VStack {
                Spacer()
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .shadow(radius: 3)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .background(Color.black.opacity(0.9))
        .overlay(
            RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var placeholder: some View {
        ZStack {
            Color.black
            Text("Превью недоступно")
                .foregroundStyle(.white.opacity(0.6))
                .font(.subheadline)
        }
    }
}
