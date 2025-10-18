//
//  PlayerLayerView.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/18/25.
//


//  PlayerLayerView.swift
//  HLSDemo2

import SwiftUI
import AVFoundation

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.player = player
    }
}

final class PlayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspectFill // <- ключевая строка
        }
    }
}
