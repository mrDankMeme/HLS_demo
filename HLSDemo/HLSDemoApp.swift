// App/App.swift
import SwiftUI

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                // Вариант для быстрой проверки гипотезы:
                // nil → автоматически найдём и запустим первый полностью открытый ролик
                SingleVideoView(videoID: nil)

                // или, если хочешь принудительно:
                // SingleVideoView(videoID: 52)
            }
        }
    }
}
