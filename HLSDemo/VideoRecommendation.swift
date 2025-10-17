// App/Domain/Models/VideoRecommendation.swift
import Foundation

public struct VideoRecommendation: Identifiable, Decodable {
    public var id: Int { video_id }
    public let video_id: Int
    public let title: String
    public let preview_image: String?
    public let duration_sec: Int?
    public let numbers_views: Int?
    public let free: Bool?                 // ← добавили
    public let time_not_reg: Int?          // ← добавили (null → nil)
    public let has_access: Bool?           // (на будущее)
}
