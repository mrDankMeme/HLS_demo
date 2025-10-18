import SwiftUI
import AVFoundation

struct ReelsDetailView: View {
    let player: AVPlayer
    let onClose: () -> Void

    @State private var comment: String = ""

    var body: some View {
        ZStack {
            PlayerSurfaceView(player: player)
                .ignoresSafeArea()

            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.55), .clear, Color.black.opacity(0.75)]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay(Image(systemName: "person.fill").foregroundColor(.white.opacity(0.9)))

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("@kristina").font(.system(size: 18, weight: .semibold))
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue)
                            }.foregroundColor(.white)

                            HStack(spacing: 6) {
                                Image(systemName: "mappin.and.ellipse")
                                Text("Россия, Сочи")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        }
                        Spacer()
                    }

                    Text("Водные просторы также впечатляют своей красотой. Вода успокаивает. Гуляю по пляжу с друзьями @anna @oleg @dasha")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .lineLimit(3)

                    HStack(spacing: 10) {
                        Image(systemName: "person.2.fill")
                        Text("Друзья смотрят: @dasha @anna @pavel").underline()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .opacity(0.95)

                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                        Text("15k смотрят эфир")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))

                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle")
                        Text("RA’MEN  ⬆︎  (12)")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ReactionChip(title: "10k", system: "face.smiling")
                            ReactionChip(title: "100k", system: "heart.fill")
                            ReactionChip(title: "5k", system: "hands.clap.fill")
                            ReactionChip(title: "300k", system: "hand.thumbsup.fill")
                            ReactionChip(title: "567", system: "face.smiling.inverse")
                        }
                    }

                    HStack {
                        TextField("Добавить комментарий", text: $comment)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(.white.opacity(0.15), in: Capsule())
                            .foregroundColor(.white)

                        Button {
                            comment = ""
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .padding(12)
                                .background(.white.opacity(0.2), in: Circle())
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            // Включаем звук только здесь
            player.isMuted = false
            if player.timeControlStatus != .playing {
                player.play()
            }
        }
        .onDisappear {
            // Возвращаем mute при уходе с деталки
            player.isMuted = true
        }
    }
}

private struct ReactionChip: View {
    let title: String
    let system: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: system)
            Text(title)
        }
        .font(.system(size: 14, weight: .semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.35), in: Capsule())
        .foregroundColor(.white)
    }
}
