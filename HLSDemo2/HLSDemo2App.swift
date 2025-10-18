//
//  HLSDemo2App.swift
//  HLSDemo2
//
//  Updated by Niiaz Khasanov on 10/18/25.
//

import SwiftUI

@main
struct HLSDemo2App: App {
    init() {
        // Регистрируем перехватчик ДО создания любых AVAsset/URLSession
        URLProtocol.registerClass(HLSSegmentURLProtocol.self)
    }

    var body: some Scene {
        WindowGroup {
            ReelsView()
        }
    }
}
