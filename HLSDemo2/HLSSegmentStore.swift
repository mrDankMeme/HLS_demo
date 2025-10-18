//
//  HLSSegmentStore.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/18/25.
//

import Foundation

/// Простой файловый сторедж для сегментов .ts/.m4s и плейлистов .m3u8
final class HLSSegmentStore {
    static let shared = HLSSegmentStore()

    private let ioQ = DispatchQueue(label: "hls.segment.store.io", qos: .utility)
    private let fm = FileManager.default
    private let root: URL

    private init() {
        let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        root = dir.appendingPathComponent("hls-segments", isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func key(for url: URL) -> String {
        // простая хеш-строка по абсолютному URL
        let s = url.absoluteString
        return String(s.hashValue) + "-" + String(s.count)
    }

    func path(for url: URL) -> URL {
        root.appendingPathComponent(key(for: url))
    }

    func has(_ url: URL) -> Bool {
        fm.fileExists(atPath: path(for: url).path)
    }

    func write(_ data: Data, for url: URL) {
        let p = path(for: url)
        ioQ.async {
            do { try data.write(to: p, options: .atomic) }
            catch { print("❌ HLSStore write error:", error.localizedDescription) }
        }
    }

    func read(_ url: URL) -> Data? {
        try? Data(contentsOf: path(for: url))
    }

    func cachedSummary() -> [String] {
        guard let files = try? fm.contentsOfDirectory(atPath: root.path) else { return [] }
        return files
    }

    func clearAll() {
        try? fm.removeItem(at: root)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
    }
}
