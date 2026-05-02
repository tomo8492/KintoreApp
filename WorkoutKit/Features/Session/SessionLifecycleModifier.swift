// MARK: - SessionLifecycleModifier
// CLAUDE.md §1.1 F-03 / §11.4 準拠。
// セッション実行中だけ画面ロックを抑止し、SceneStorage で進行状態を復元する。
// - UIApplication.shared.isIdleTimerDisabled は §11.4 で許可された Singleton 例外。
// - 自作 Singleton(.shared)は使わない、Observable Store と SceneStorage の組み合わせ。
// - ライフサイクル外で IdleTimer を立てっぱなしにしないため、view が消えたら必ず戻す。

import SwiftUI
import UIKit
import OSLog

struct SessionLifecycleModifier: ViewModifier {
    let store: SessionStore
    @Binding var snapshotString: String

    func body(content: Content) -> some View {
        content
            .onAppear { handleAppear() }
            .onDisappear { handleDisappear() }
            .onChange(of: store.currentItemIndex) { _, _ in writeSnapshot() }
            .onChange(of: store.currentSetIndex) { _, _ in writeSnapshot() }
            .onChange(of: store.status) { _, newStatus in
                if newStatus != .running {
                    // 終了/中断時は復元情報をクリアして次回起動でゴミが残らないようにする。
                    snapshotString = ""
                }
            }
    }

    private func handleAppear() {
        if store.status == .running {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        writeSnapshot()
    }

    private func handleDisappear() {
        // セッションが続いていてもいなくても、画面から離れたら必ず IdleTimer を戻す。
        UIApplication.shared.isIdleTimerDisabled = false
        // 一時退避(マルチタスク復帰用)に最新スナップショットを書いておく。
        if store.status == .running {
            writeSnapshot()
        }
    }

    private func writeSnapshot() {
        guard store.status == .running else { return }
        if let encoded = store.snapshot().encoded() {
            snapshotString = encoded
        } else {
            Logger.session.warning("SessionLifecycleModifier: snapshot encode failed")
        }
    }
}

extension View {
    /// SessionView がライフサイクル(idle timer / SceneStorage)を扱うためのフック。
    func sessionLifecycle(
        store: SessionStore,
        snapshotString: Binding<String>
    ) -> some View {
        modifier(SessionLifecycleModifier(store: store, snapshotString: snapshotString))
    }
}
