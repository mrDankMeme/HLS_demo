//
//  ReelsPreheater.swift
//  HLSDemo2
//
//  Updated by Niiaz Khasanov on 10/18/25
//

import Foundation
import AVFoundation

final class ReelsPreheater {
    private var cache: [Int: AVURLAsset] = [:]
    private var order: [Int] = []
    private let maxItems: Int = 6
    private let queue = DispatchQueue(label: "reels.preheater")

    private let segmentPrefetcher = HLSSegmentPrefetcher.shared

    func asset(for videoID: Int) -> AVURLAsset {
        if let a = cache[videoID] {
            print("🎯 asset cache HIT (memory) videoID=\(videoID)")
            return a
        }
        let url = InteresnoAPI.hlsPlaylistURL(videoID: videoID)
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "User-Agent": "HLSDemo2/1.0 (iOS)",
                "Accept": "application/vnd.apple.mpegurl, application/x-mpegURL, */*"
            ]
        ])
        cache[videoID] = asset
        order.append(videoID)
        trimIfNeeded()
        asset.loadValuesAsynchronously(forKeys: ["playable"]) { }
        print("➕ asset cache MISS -> stored videoID=\(videoID)")
        return asset
    }

    func prefetchCurrent(videoID: Int) {
        let url = InteresnoAPI.hlsPlaylistURL(videoID: videoID)
        segmentPrefetcher.prefetchFirstSeconds(from: url, seconds: 60)
    }

    func warmNeighbors(currentIndex: Int, items: [VideoRecommendation]) {
        let indices = [currentIndex - 2, currentIndex - 1, currentIndex + 1, currentIndex + 2]
            .filter { $0 >= 0 && $0 < items.count }
        queue.async { [weak self] in
            guard let self else { return }
            for i in indices {
                let id = items[i].video_id
                let url = InteresnoAPI.hlsPlaylistURL(videoID: id)
                self.segmentPrefetcher.prefetchFirstSeconds(from: url, seconds: 60)
                _ = self.asset(for: id)
            }
        }
    }

    private func trimIfNeeded() {
        while order.count > maxItems {
            let removeID = order.removeFirst()
            cache.removeValue(forKey: removeID)
            print("🧹 asset cache EVICT videoID=\(removeID)")
        }
    }
}
