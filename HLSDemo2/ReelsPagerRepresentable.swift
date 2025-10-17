//
//  ReelsPagerRepresentable.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//

import SwiftUI
import AVFoundation

struct ReelsPagerRepresentable: UIViewControllerRepresentable {
    let items: [VideoRecommendation]
    let activeID: Int?
    let player: AVPlayer
    let onActiveIndexChanged: (Int) -> Void

    func makeUIViewController(context: Context) -> ReelsPagerViewController {
        let vc = ReelsPagerViewController()
        vc.sharedPlayer = player
        vc.onActiveIndexChanged = onActiveIndexChanged
        return vc
    }

    func updateUIViewController(_ ui: ReelsPagerViewController, context: Context) {
        ui.sharedPlayer = player
        ui.setItems(items)
        ui.setActiveVideoID(activeID) // без программного скролла
    }
}
