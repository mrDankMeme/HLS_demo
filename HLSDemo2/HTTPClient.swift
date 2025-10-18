//
//  HTTPClient.swift
//  HLSDemo2
//
//  Updated by Niiaz Khasanov on 10/18/25
//

import Foundation

public protocol HTTPClient {
    func get(url: URL) async throws -> (Data, HTTPURLResponse)
}

public final class DefaultHTTPClient: HTTPClient {
    private let session: URLSession

    public init() {
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = URLCache(
            memoryCapacity: 512 * 1024 * 1024,
            diskCapacity:   512 * 1024 * 1024,
            diskPath:       "http-cache"
        )
        cfg.requestCachePolicy = .useProtocolCachePolicy
        cfg.timeoutIntervalForRequest  = 10
        cfg.timeoutIntervalForResource = 15
        cfg.waitsForConnectivity = true
        cfg.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "HLSDemo2/1.0 (iOS)"
        ]
        self.session = URLSession(configuration: cfg)
    }

    public func get(url: URL) async throws -> (Data, HTTPURLResponse) {
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}
