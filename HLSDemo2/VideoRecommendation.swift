//
//  VideoRecommendation.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//

import Foundation
public struct VideoRecommendation: Identifiable, Decodable, Hashable {
    public var id: Int { video_id }
    public let video_id: Int
    public let title: String
    public let preview_image: String?
    public let duration_sec: Int?
    public let numbers_views: Int?
    public let free: Bool?
    public let time_not_reg: Int?
    public let has_access: Bool?
}
