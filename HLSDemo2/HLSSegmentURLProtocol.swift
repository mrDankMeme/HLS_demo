//
//  HLSSegmentURLProtocol.swift
//  HLSDemo2
//
//  Updated by Niiaz Khasanov on 10/18/25
//

import Foundation

/// Перехватывает *.m3u8/*.ts/*.m4s/*.aac.
/// Если сегмент есть в кэше — отдаём из диска; иначе — качаем и кладём.
final class HLSSegmentURLProtocol: URLProtocol {
    private static let handledKey = "HLSSegmentURLProtocolHandled"
    private let store = HLSSegmentStore.shared
    private var dataTask: URLSessionDataTask?

    // ✅ Один общий URLSession для всех запросов (keep-alive, минимальная конкуренция с плеером)
    private static let sharedSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.httpMaximumConnectionsPerHost = 1   // было 4 — забивало сокеты плееру
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 60
        cfg.waitsForConnectivity = true
        cfg.httpAdditionalHeaders = [
            "User-Agent": "HLSDemo2/1.0 (iOS)",
            "Accept": "application/vnd.apple.mpegurl, application/x-mpegURL, */*"
        ]
        return URLSession(configuration: cfg)
    }()

    override class func canInit(with request: URLRequest) -> Bool {
        if URLProtocol.property(forKey: handledKey, in: request) as? Bool == true { return false }
        guard let url = request.url else { return false }
        switch url.pathExtension.lowercased() {
        case "ts", "m4s", "aac", "m3u8": return true
        default: return false
        }
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }

        // Кеш-хит — сразу из диска
        if let data = store.read(url) {
            print("📀 URLProtocol serve from cache:", url.lastPathComponent)
            let mime: String
            switch url.pathExtension.lowercased() {
            case "m3u8": mime = "application/vnd.apple.mpegurl"
            case "ts":   mime = "video/MP2T"
            case "m4s":  mime = "video/iso.segment"
            case "aac":  mime = "audio/aac"
            default:     mime = "application/octet-stream"
            }
            let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": mime])!
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        // Качаем «на лету», помечаем чтобы не зациклиться
        let mutableReq = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: HLSSegmentURLProtocol.handledKey, in: mutableReq)

        dataTask = HLSSegmentURLProtocol.sharedSession.dataTask(with: mutableReq as URLRequest) { [weak self] data, resp, err in
            guard let self else { return }
            if let resp = resp { self.client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed) }
            if let data = data {
                self.client?.urlProtocol(self, didLoad: data)
                self.store.write(data, for: url) // 💾 положили в кэш
                print("💾 cached on demand:", url.lastPathComponent)
            }
            if let err = err { self.client?.urlProtocol(self, didFailWithError: err) }
            else { self.client?.urlProtocolDidFinishLoading(self) }
        }
        dataTask?.priority = URLSessionTask.lowPriority  // самый низкий приоритет
        dataTask?.resume()
    }

    override func stopLoading() {
        dataTask?.cancel()
        dataTask = nil
    }
}
