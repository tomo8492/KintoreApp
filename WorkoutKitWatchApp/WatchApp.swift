// MARK: - WatchQuickLogApp
// Phase 2-2 (Watch 単体記録) 準拠。
//
// watchOS 単体アプリのエントリーポイント。QuickLogView をルートに置き、
// WatchSyncClient を Environment 経由で全画面に注入する。
// WCSession の activate() は起動直後の .task で 1 回だけ呼ぶ。

import SwiftUI

@main
struct WatchQuickLogApp: App {
    @State private var syncClient = WatchSyncClient.shared

    var body: some Scene {
        WindowGroup {
            QuickLogView()
                .environment(syncClient)
                .task {
                    syncClient.activate()
                }
        }
    }
}
