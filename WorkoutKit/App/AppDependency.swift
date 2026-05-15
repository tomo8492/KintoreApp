// MARK: - AppDependency
// CLAUDE.md v1.0 §4-1 / §4-3 準拠。
// `@Observable` クラスは `.environment(...)` で個別注入し、それ以外の値型 /
// プロトコル抽象は本 struct でまとめて配る。

import Foundation
import SwiftUI

/// アプリ全体の依存をまとめる。`@Observable` ではなく struct にして
/// 軽量に値渡しできる形にしておく(ストアは内側で MainActor / actor 隔離)。
struct AppDependency {
    var proGate: ProFeatureGate
    /// C3: Live Activity ラッパー(セッション進捗用)。SessionStore に DI して使う。
    var liveActivity: LiveActivityClient
    /// v1.0 §5-3: レストタイマー専用 Live Activity マネージャ。
    /// SessionStore.completeCurrentSet から呼ばれる(後続コミットで配線)。
    var restTimer: RestTimerManager
    /// v1.0 §6-4: RevenueCat ラッパ。Offering / 購入 / 復元 / isPremium を集約。
    /// `PurchaseManager.shared` を入れる(View 階層に直接渡したい場合は
    /// `.environment(PurchaseManager.shared)` を併用)。
    var purchaseManager: PurchaseManager
    /// 旧 StoreKit 2 クライアント。`StoreKitClientTests` の互換のため残置。
    /// 新規コードからは利用せず、PurchaseManager を使う。
    var storeKitClient: StoreKitClient
    /// E3 Settings から呼ぶ Restore Purchase の抽象。v1.0 では PurchaseManager
    /// (RevenueCat 経由)を本番実装として配線する。Preview / 未統合ビルドでは
    /// NoopPurchaseRestorer に差し替え可能。
    var purchaseRestorer: any PurchaseRestoring
    /// F-02 詳細画面で使う「動作矢印 + アノテーション」JSON ローダー。
    /// Bundle 越しに lazy にロードしプロセス内でキャッシュする。
    var annotationLoader: ExerciseAnnotationLoader
}

// MARK: - SwiftUI Environment 拡張
// `@Environment(\.appDependency)` で View から取り出せるようにする。

private struct AppDependencyKey: EnvironmentKey {
    /// プロトコル要件は nonisolated。
    /// ProFeatureGate / LiveActivityClient / RestTimerManager は nonisolated init、
    /// StoreKitClient は actor の暗黙 nonisolated init、PurchaseManager.shared は
    /// nonisolated(unsafe) static let なのですべて nonisolated context から構築可。
    static let defaultValue: AppDependency = {
        let gate = ProFeatureGate()
        let storeKit = StoreKitClient(proGate: gate)
        return AppDependency(
            proGate: gate,
            liveActivity: LiveActivityClient(),
            restTimer: RestTimerManager.shared,
            purchaseManager: PurchaseManager.shared,
            storeKitClient: storeKit,
            // v1.0: サブスク entitlement を RevenueCat 経由で復元するため
            // PurchaseManager.shared を Restore 実装として配線する。
            purchaseRestorer: PurchaseManager.shared,
            annotationLoader: ExerciseAnnotationLoader()
        )
        // 注意: PurchaseManager → ProFeatureGate の bridge 配線(proGateBridge への
        //       クロージャ設定)はここで行わない。defaultValue は nonisolated 評価
        //       されるため、@MainActor の proGateBridge プロパティに書き込めない。
        //       配線は @main の WorkoutKitApp.init(@MainActor)側で実施する。
    }()
}

extension EnvironmentValues {
    var appDependency: AppDependency {
        get { self[AppDependencyKey.self] }
        set { self[AppDependencyKey.self] = newValue }
    }
}
