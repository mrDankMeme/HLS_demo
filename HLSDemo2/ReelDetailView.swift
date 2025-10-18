//
//  ReelDetailView.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/18/25.
//

import SwiftUI
import AVKit

struct ReelDetailView: View {
    let video: VideoRecommendation
    let sharedPlayer: AVPlayer

    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""

    var body: some View {
        ZStack {
            // один и тот же AVPlayer — не создаём новый, просто показываем слой
            PlayerLayerView(player: sharedPlayer)
                .ignoresSafeArea()
                .onAppear {
                    sharedPlayer.isMuted = false
                    sharedPlayer.play()
                }
                .onDisappear {
                    // назад в ленте оставим плеер в mute
                    sharedPlayer.isMuted = true
                }

            VStack {
                topSection
                Spacer()
                bottomSection
            }
            .padding(.top, 44)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.85)],
                    startPoint: .center, endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
        }
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .topLeading) {
            Button {
                sharedPlayer.isMuted = true
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Circle())
                    .padding(.top, 50)
                    .padding(.leading, 12)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                // share
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Circle())
                    .padding(.top, 50)
                    .padding(.trailing, 12)
            }
        }
    }

    // MARK: Верхний блок
    private var topSection: some View {
        HStack(alignment: .top, spacing: 16) {
            avatarBlock
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("@kristina")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color(red: 0.27, green: 0.56, blue: 1.0))
                        .font(.system(size: 20))
                }
                Label("Россия, Сочи", systemImage: "mappin.and.ellipse")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Text(video.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: Нижний блок
    private var bottomSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            friendsAndViewers
            locationBlock
            hashtagsBlock
            reactionsBlock
            commentField
        }
        .padding(.bottom, 30)
    }

    private var friendsAndViewers: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill").foregroundStyle(.white)
                Text("Друзья смотрят: ")
                    .foregroundStyle(.white)
                + Text("@dasha @anna @pavel")
                    .foregroundStyle(.white).fontWeight(.semibold)
            }
            HStack(spacing: 8) {
                Image(systemName: "play.fill").foregroundStyle(.white)
                Text("15k смотрят эфир").foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
    }

    private var locationBlock: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse").foregroundStyle(.white)
            Text("RA'MEN").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            Image(systemName: "arrow.up.right.circle.fill").foregroundStyle(Color.green)
            HStack(spacing: 6) {
                Image(systemName: "film").foregroundStyle(.white)
                Text("(12)").font(.system(size: 16)).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
    }

    private var hashtagsBlock: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(["#португалия", "#природа", "#лето"], id: \.self) { t in
                    Text(t)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var reactionsBlock: some View {
        HStack(spacing: 18) {
            reaction("😍", "10k")
            reaction("❤️", "100k")
            reaction("🙈", "5k")
            reaction("👍", "300k")
            reaction("☺️", "567")
        }
        .padding(.horizontal, 20)
    }

    private func reaction(_ emoji: String, _ count: String) -> some View {
        HStack(spacing: 6) {
            Text(emoji).font(.system(size: 20))
            Text(count).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.3))
        .clipShape(Capsule())
    }

    private var commentField: some View {
        HStack(spacing: 10) {
            TextField("Добавить комментарий", text: $commentText)
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(Color.white.opacity(0.18))
                .cornerRadius(25)
                .foregroundColor(.white)
            Button {
                commentText = ""
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
    }

    private var avatarBlock: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.95), lineWidth: 4)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                )
                .frame(width: 116, height: 152)

            Text("Live")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(red: 1.00, green: 0.30, blue: 0.22))
                .clipShape(Capsule())
                .offset(y: 10)
        }
    }
}
