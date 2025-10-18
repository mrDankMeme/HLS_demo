//
//  HLSPlaylistParser.swift
//  HLSDemo2
//
//  Updated by Niiaz Khasanov on 10/18/25.
//

import Foundation

struct HLSSegment {
    let url: URL
    let duration: Double
}

struct HLSVariant {
    let url: URL
    let bandwidth: Int // bits per second
}

enum HLSPlaylistKind { case master, media }

/// Небольшой парсер .m3u8: вытаскивает сегменты и варианты (с BANDWIDTH).
enum HLSPlaylistParser {

    static func parse(baseURL: URL, data: Data) -> (kind: HLSPlaylistKind, segments: [HLSSegment], variants: [HLSVariant]) {
        guard let text = String(data: data, encoding: .utf8) else { return (.media, [], []) }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var segments: [HLSSegment] = []
        var variants: [HLSVariant] = []
        var currentDuration: Double?
        var pendingBW: Int?

        for i in 0..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)

            // master: EXT-X-STREAM-INF:...BANDWIDTH=...
            if line.hasPrefix("#EXT-X-STREAM-INF") {
                pendingBW = extractBandwidth(from: line)
                if i+1 < lines.count {
                    let next = lines[i+1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if let u = URL(string: next, relativeTo: baseURL) {
                        variants.append(.init(url: u, bandwidth: pendingBW ?? .max))
                    }
                }
                continue
            }

            // media: EXTINF: <duration>,
            if line.hasPrefix("#EXTINF:") {
                let num = line.dropFirst("#EXTINF:".count)
                currentDuration = Double(num.split(separator: ",").first ?? "") ?? nil
                continue
            }

            // skip comments & blanks
            if line.isEmpty || line.hasPrefix("#") { continue }

            // media segment line (or nested playlist)
            if let u = URL(string: line, relativeTo: baseURL) {
                if let d = currentDuration {
                    segments.append(.init(url: u, duration: d))
                    currentDuration = nil
                } else {
                    // это может быть вариант без явного EXT-X-STREAM-INF — занесём как variant с неизвестным BW
                    variants.append(.init(url: u, bandwidth: pendingBW ?? .max))
                }
            }
        }

        if !variants.isEmpty && segments.isEmpty {
            return (.master, [], variants)
        } else {
            return (.media, segments, [])
        }
    }

    private static func extractBandwidth(from streamInf: String) -> Int? {
        // ищем BANDWIDTH=число
        // пример: #EXT-X-STREAM-INF:BANDWIDTH=640000,AVERAGE-BANDWIDTH=600000,RESOLUTION=...
        guard let range = streamInf.range(of: "BANDWIDTH=") else { return nil }
        let tail = streamInf[range.upperBound...]
        let number = tail.prefix { ch in ch.isNumber }
        return Int(number)
    }
}
