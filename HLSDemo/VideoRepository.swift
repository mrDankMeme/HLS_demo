// App/Infrastructure/Repositories/VideoRepository.swift
import Foundation

public protocol VideoRepository {
    func fetchRecommendations(offset: Int, limit: Int) async throws -> [VideoRecommendation]
}

public final class DefaultVideoRepository: VideoRepository {
    private let client: HTTPClient
    public init(client: HTTPClient) { self.client = client }

    private struct RecResponse: Decodable {
        let items: [VideoRecommendation]
    }

    public func fetchRecommendations(offset: Int, limit: Int) async throws -> [VideoRecommendation] {
        let url = InteresnoAPI.recommendationsURL(offset: offset, limit: limit)
        let (data, http) = try await client.get(url: url)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(RecResponse.self, from: data).items
    }
}
