//
//  ReelsPreheater.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//

import Foundation
import AVFoundation

/// Лёгкий преподгрев: заранее грузим плейлисты (manifest) для соседних видео.
final class ReelsPreheater {
    private var cache: [Int: AVURLAsset] = [:]
    private var order: [Int] = []
    private let maxItems: Int = 6
    private let queue = DispatchQueue(label: "reels.preheater")

    func asset(for videoID: Int) -> AVURLAsset {
        if let a = cache[videoID] { return a }
        let url = InteresnoAPI.hlsPlaylistURL(videoID: videoID)
        let asset = AVURLAsset(url: url)
        cache[videoID] = asset
        order.append(videoID)
        trimIfNeeded()
        asset.loadValuesAsynchronously(forKeys: ["playable"]) {
            var error: NSError?
            _ = asset.statusOfValue(forKey: "playable", error: &error)
            if let error { print("🔮 preheat playable error:", error.localizedDescription) }
        }
        return asset
    }

    func warmNeighbors(currentIndex: Int, items: [VideoRecommendation]) {
        let indices = [currentIndex - 2, currentIndex - 1, currentIndex + 1, currentIndex + 2]
            .filter { $0 >= 0 && $0 < items.count }
        queue.async { [weak self] in
            guard let self else { return }
            for i in indices {
                let id = items[i].video_id
                _ = self.asset(for: id)
            }
        }
    }

    private func trimIfNeeded() {
        while order.count > maxItems {
            let removeID = order.removeFirst()
            cache.removeValue(forKey: removeID)
        }
    }
}
