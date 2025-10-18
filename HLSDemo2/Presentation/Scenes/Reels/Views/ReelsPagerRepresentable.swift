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

    
    let isShowingDetail: Bool

    // колбэки
    let onActiveIndexChanged: (Int) -> Void
    let onTapActive: () -> Void

    func makeUIViewController(context: Context) -> ReelsPagerViewController {
        let vc = ReelsPagerViewController()
        vc.sharedPlayer = player
        vc.onActiveIndexChanged = onActiveIndexChanged
        vc.onTapActive = onTapActive
        return vc
    }

    func updateUIViewController(_ ui: ReelsPagerViewController, context: Context) {
        ui.sharedPlayer = player
        ui.setItems(items)

        
        
        ui.setDetailShown(isShowingDetail)
        ui.setActiveVideoID(activeID)
    }
}
