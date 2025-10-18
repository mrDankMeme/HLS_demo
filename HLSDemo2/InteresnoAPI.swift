//
//  InteresnoAPI.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//

import Foundation

public enum InteresnoAPI {
    public static let base = URL(string: "https://interesnoitochka.ru/api/v1")!

    public static func hlsPlaylistURL(videoID: Int) -> URL {
        base.appendingPathComponent("videos/video/\(videoID)/hls/playlist.m3u8")
    }

    public static func recommendationsURL(offset: Int = 0, limit: Int = 20) -> URL {
        var comps = URLComponents(url: base.appendingPathComponent("videos/recommendations"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "offset", value: String(offset)),
            .init(name: "limit", value: String(limit)),
            .init(name: "category", value: "shorts"),
            .init(name: "date_filter_type", value: "created"),
            .init(name: "sort_by", value: "date_created"),
            .init(name: "sort_order", value: "desc"),
            .init(name: "is_free", value: "true"),
            .init(name: "auth_required", value: "false")
        ]
        return comps.url!
    }
}
