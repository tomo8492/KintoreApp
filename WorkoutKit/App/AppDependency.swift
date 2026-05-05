// MARK: - AppDependency
// CLAUDE.md §4.1 準拠。Singleton(.shared) を禁じる代わりの DI ルート。
// View には @Environment / @Bindable で注入する。

import Foundation
import SwiftUI

/// アプリ全体の依存をまとめる。`@Observable` ではなく struct にして
/// 軽量に値渡しできる形にしておく(ストアは内側で MainActor / actor 隔離)。
struct AppDependency {
    var proGate: ProFeatureGate
    /// C3: Live Activity ラッパー。SessionStore に DI して使う。
    var liveActivity: LiveActivityClient
    /// StoreKit 2 クライアント。actor なので参照渡しで OK。
    var storeKitClient: StoreKitClient
    /// E3 Settings から呼ぶ Restore Purchase の抽象。本番は StoreKitClient
    /// を渡し、Preview / 未統合ビルドでは NoopPurchaseRestorer に差し替える。
    var purchaseRestorer: any PurchaseRestoring
    /// F-02 詳細画面で使う「動作矢印 + アノテーション」JSON ローダー。
    /// Bundle 越しに lazy にロードしプロセス内でキャッシュする。
    var annotationLoader: ExerciseAnnotationLoader
}

// MARK: - SwiftUI Environment 拡張
// `@Environment(\.appDependency)` で View から取り出せるようにする。

private struct AppDependencyKey: EnvironmentKey {
    /// プロトコル要件は nonisolated。
    /// ProFeatureGate.init() / LiveActivityClient.init() は nonisolated 化済み。
    /// StoreKitClient.init は actor の暗黙 nonisolated init。
    static let defaultValue: AppDependency = {
        let gate = ProFeatureGate()
        let storeKit = StoreKitClient(proGate: gate)
        return AppDependency(
            proGate: gate,
            liveActivity: LiveActivityClient(),
            storeKitClient: storeKit,
            purchaseRestorer: storeKit,
            annotationLoader: ExerciseAnnotationLoader()
        )
    }()
}

extension EnvironmentValues {
    var appDependency: AppDependency {
        get { self[AppDependencyKey.self] }
        set { self[AppDependencyKey.self] = newValue }
    }
}
