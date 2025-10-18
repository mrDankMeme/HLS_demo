//
//  HLSCacheItem.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/18/25.
//


//
//  HLSProxy.swift
//  HLSDemo2
//
//  Локальный reverse-proxy c дисковым кешем для HLS (.m3u8, .ts, .m4s, .m4a, .mp4).
//  Переписывает m3u8 так, чтобы ВСЕ сегменты и ключи шли через 127.0.0.1,
//  поэтому AVPlayer всегда использует наш кеш.
//
//  Зависимости (SPM):
//  - https://github.com/yene/GCDWebServer
//  - https://github.com/hyperoslo/Cache
//

import Foundation
import GCDWebServer
import Cache
import CryptoKit

struct HLSCacheItem: Codable {
    let data: Data
    let url: URL
    let mimeType: String
}

final class HLSProxy {
    static let shared = HLSProxy()

    private let web = GCDWebServer()
    private let port: UInt = 12345
    private let originKey = "__origin"

    private let session: URLSession
    private let cache: Storage<String, HLSCacheItem>

    private init() {
        // URLSession
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest = 10
        cfg.timeoutIntervalForResource = 25
        cfg.httpAdditionalHeaders = [
            "User-Agent": "HLSDemo2/1.0 (iOS)",
            "Accept": "application/vnd.apple.mpegurl, application/x-mpegURL, */*"
        ]
        session = URLSession(configuration: cfg)

        // Cache (300MB на диск, без экспирации, LRU управляет hyperoslo/Cache)
        let disk = DiskConfig(name: "HLSProxy", expiry: .never, maxSize: 300 * 1024 * 1024)
        let mem  = MemoryConfig(expiry: .never, countLimit: 64, totalCostLimit: 64)
        cache = try! Storage<String, HLSCacheItem>(
            diskConfig:   disk,
            memoryConfig: mem,
            fileManager:  .default,
            transformer:  TransformerFactory.forCodable(ofType: HLSCacheItem.self)
        )

        addHandler()
        start()
    }

    deinit { web.stop() }

    // MARK: Public API

    /// Прокси-URL для AVPlayer/AVURLAsset вместо оригинального.
    func proxyURL(for origin: URL) -> URL {
        var c = URLComponents()
        c.scheme = "http"
        c.host   = "127.0.0.1"
        c.port   = Int(port)
        // путь сохраняем, чтобы плеер не смущался относительных путей
        c.path   = origin.path.isEmpty ? "/" : origin.path

        var items = origin.queryItems
        items.append(.init(name: originKey, value: origin.absoluteString))
        c.queryItems = items
        return c.url!
    }

    /// Горячий префетч первых N секунд плейлиста (скачивается через прокси → в дисковый кеш).
    func prefetchFirstSeconds(from originPlaylist: URL, seconds: Double, completion: (() -> Void)? = nil) {
        let m3u8 = proxyURL(for: originPlaylist)
        session.dataTask(with: m3u8) { [weak self] data, _, _ in
            guard let self, let data, let text = String(data: data, encoding: .utf8) else {
                completion?(); return
            }
            let segments = self.parseSegments(from: text, origin: originPlaylist)
            var acc = 0.0
            let group = DispatchGroup()
            for seg in segments {
                if acc >= seconds { break }
                acc += seg.duration
                group.enter()
                let url = self.proxyURL(for: seg.url)
                self.session.dataTask(with: url) { _, _, _ in group.leave() }.resume()
            }
            group.notify(queue: .main) { completion?() }
        }.resume()
    }

    // MARK: Web server

    private func start() {
        guard !web.isRunning else { return }
        web.start(withPort: port, bonjourName: nil)
        print("🌐 HLSProxy started at http://127.0.0.1:\(port)")
    }

    private func addHandler() {
        web.addHandler(forMethod: "GET", pathRegex: "^/.*\\.*$", request: GCDWebServerRequest.self) { [weak self] req, finish in
            guard let self, let origin = self.extractOrigin(from: req) else {
                return finish(GCDWebServerErrorResponse(statusCode: 400))
            }

            let ext = origin.pathExtension.lowercased()

            // m3u8 — читаем из кеша или качаем, сохраняем, переписываем и отдаём
            if ext == "m3u8" {
                if let cached = self.read(origin) {
                    if let out = self.rewritePlaylistData(cached, origin: origin) {
                        print("✅ m3u8 DISK:", origin.lastPathComponent)
                        return finish(GCDWebServerDataResponse(data: out, contentType: cached.mimeType))
                    } else {
                        return finish(GCDWebServerErrorResponse(statusCode: 500))
                    }
                }

                self.fetch(origin) { data, mime in
                    guard let data, let mime else {
                        return finish(GCDWebServerErrorResponse(statusCode: 502))
                    }
                    let item = HLSCacheItem(data: data, url: origin, mimeType: mime)
                    self.write(item)
                    if let out = self.rewritePlaylistData(item, origin: origin) {
                        print("⬇️ m3u8 NET→DISK:", origin.lastPathComponent)
                        finish(GCDWebServerDataResponse(data: out, contentType: mime))
                    } else {
                        finish(GCDWebServerErrorResponse(statusCode: 500))
                    }
                }
                return
            }

            // Сегменты и ключи
            if ["ts","m4s","m4a","m4v","mp4","aac","key"].contains(ext) {
                if let cached = self.read(origin) {
                    print("✅ segment DISK:", origin.lastPathComponent)
                    return finish(GCDWebServerDataResponse(data: cached.data, contentType: cached.mimeType))
                }
                self.fetch(origin) { data, mime in
                    guard let data, let mime else {
                        return finish(GCDWebServerErrorResponse(statusCode: 502))
                    }
                    let forced = ext == "mp4" ? "video/mp4" : mime
                    let item = HLSCacheItem(data: data, url: origin, mimeType: forced)
                    self.write(item)
                    print("⬇️ segment NET→DISK:", origin.lastPathComponent)
                    finish(GCDWebServerDataResponse(data: data, contentType: forced))
                }
                return
            }

            // Прочее просто проксируем
            self.fetch(origin) { data, mime in
                guard let data, let mime else { return finish(GCDWebServerErrorResponse(statusCode: 502)) }
                finish(GCDWebServerDataResponse(data: data, contentType: mime))
            }
        }
    }

    // MARK: Helpers

    private func extractOrigin(from req: GCDWebServerRequest) -> URL? {
        guard let enc = req.query?[originKey],
              let str = enc.removingPercentEncoding,
              let url = URL(string: str) else { return nil }
        return url
    }

    private func fetch(_ url: URL, completion: @escaping (Data?, String?) -> Void) {
        session.dataTask(with: url) { data, resp, _ in
            completion(data, resp?.mimeType)
        }.resume()
    }

    private func read(_ url: URL) -> HLSCacheItem? {
        try? cache.object(forKey: key(url))
    }

    private func write(_ item: HLSCacheItem) {
        try? cache.setObject(item, forKey: key(item.url))
    }

    private func key(_ url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format:"%02hhx",$0) }.joined()
    }

    private func rewritePlaylistData(_ item: HLSCacheItem, origin: URL) -> Data? {
        guard let text = String(data: item.data, encoding: .utf8) else { return nil }
        let out = text
            .components(separatedBy: .newlines)
            .map { self.rewrite(line: $0, origin: origin) }
            .joined(separator: "\n")
        return out.data(using: .utf8)
    }

    private func rewrite(line: String, origin: URL) -> String {
        guard !line.isEmpty else { return line }

        if line.hasPrefix("#") {
            // Переписываем URI="..." (ключи, субтитры)
            let rx = try! NSRegularExpression(pattern: "URI=\"([^\"]*)\"")
            let ns = line as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let m = rx.firstMatch(in: line, range: range) else { return line }
            let uri = ns.substring(with: m.range(at: 1))
            guard let abs = absolute(uri, origin: origin) else { return line }
            let prox = proxyURL(for: abs).absoluteString
            return rx.stringByReplacingMatches(in: line, range: range, withTemplate: "URI=\"\(prox)\"")
        }

        // Строка сегмента
        if let abs = absolute(line, origin: origin) {
            return proxyURL(for: abs).absoluteString
        }
        return line
    }

    private func absolute(_ s: String, origin: URL) -> URL? {
        if s.hasPrefix("http://") || s.hasPrefix("https://") { return URL(string: s) }
        let base = origin.deletingLastPathComponent()
        if s.hasPrefix("/") {
            var c = URLComponents()
            c.scheme = origin.scheme
            c.host   = origin.host
            c.port   = origin.port
            c.path   = s
            return c.url?.standardized
        } else {
            return base.appendingPathComponent(s).standardized
        }
    }
}

// MARK: - Helpers

private extension URL {
    var queryItems: [URLQueryItem] {
        var c = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        var items = c.queryItems ?? []
        items.sort { $0.name < $1.name }
        return items
    }
}

private struct HLSSeg {
    let url: URL
    let duration: Double
}

private extension HLSProxy {
    /// Очень простой парсер EXTINF/url из m3u8
    func parseSegments(from playlistText: String, origin: URL) -> [HLSSeg] {
        var durs: [Double] = []
        var urls: [URL] = []
        for line in playlistText.components(separatedBy: .newlines) {
            if line.hasPrefix("#EXTINF:") {
                let num = line.dropFirst("#EXTINF:".count)
                if let dur = Double(num.split(separator: ",").first ?? "0") { durs.append(dur) }
            } else if !line.isEmpty && !line.hasPrefix("#") {
                if let u = absolute(line, origin: origin) { urls.append(u) }
            }
        }
        var res: [HLSSeg] = []
        for i in 0..<min(durs.count, urls.count) {
            res.append(.init(url: urls[i], duration: durs[i]))
        }
        return res
    }
}
