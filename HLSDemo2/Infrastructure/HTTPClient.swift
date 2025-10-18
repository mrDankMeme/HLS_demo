//
//  HTTPClient.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//

import Foundation

public protocol HTTPClient {
    func get(url: URL) async throws -> (Data, HTTPURLResponse)
}

public final class DefaultHTTPClient: HTTPClient {
    private let session: URLSession

    public init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        cfg.timeoutIntervalForResource = 15
        cfg.waitsForConnectivity = true
        cfg.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "HLSDemo2/1.0 (iOS)"
        ]
        self.session = URLSession(configuration: cfg)
    }

    public func get(url: URL) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadRevalidatingCacheData
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}
