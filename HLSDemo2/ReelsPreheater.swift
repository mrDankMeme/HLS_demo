//
//  ReelsPreheater.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//

import Foundation
import AVFoundation

/// Преподгрев и кеш через локальный reverse-proxy.
/// Мы создаём AVURLAsset на проксированный URL, поэтому AVPlayer всегда ходит через прокси,
/// а прокси — кэширует m3u8 и сегменты на диск.
final class ReelsPreheater {
    private var cache: [Int: AVURLAsset] = [:]
    private var order: [Int] = []
    private let maxItems: Int = 6
    private let queue = DispatchQueue(label: "reels.preheater")

    /// Возвращаем asset, указывающий на локальный прокси (127.0.0.1).
    func asset(for videoID: Int) -> AVURLAsset {
        if let a = cache[videoID] { return a }
        let origin = InteresnoAPI.hlsPlaylistURL(videoID: videoID)
        let proxied = HLSProxy.shared.proxyURL(for: origin)
        let asset = AVURLAsset(url: proxied)
        cache[videoID] = asset
        order.append(videoID)
        trimIfNeeded()
        // мягкая прогрузка playable (не блокирует)
        asset.loadValuesAsynchronously(forKeys: ["playable"]) {
            var error: NSError?
            _ = asset.statusOfValue(forKey: "playable", error: &error)
            if let error { print("🔮 preheat playable error:", error.localizedDescription) }
        }
        return asset
    }

    /// Прогреваем ±2 соседа и по 60s для каждого (если короче — возьмём меньше).
    func warmNeighbors(currentIndex: Int, items: [VideoRecommendation]) {
        let indices = [currentIndex - 2, currentIndex - 1, currentIndex + 1, currentIndex + 2]
            .filter { $0 >= 0 && $0 < items.count }

        queue.async {
            for i in indices {
                let id = items[i].video_id
                _ = self.asset(for: id) // чтобы кэш asset'ов не выкидывался
                let origin = InteresnoAPI.hlsPlaylistURL(videoID: id)
                HLSProxy.shared.prefetchFirstSeconds(from: origin, seconds: 60)
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
