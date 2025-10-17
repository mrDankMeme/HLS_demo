// App/Core/Networking/HTTPClient.swift
import Foundation

public protocol HTTPClient {
    func get(url: URL) async throws -> (Data, HTTPURLResponse)
}

public final class DefaultHTTPClient: HTTPClient {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func get(url: URL) async throws -> (Data, HTTPURLResponse) {
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}
