// MARK: - ProFeatureGate
// CLAUDE.md §-1.14 準拠。Pro 判定は必ずこのクラス経由(NGリスト規約)。
// v1.0 では RevenueCat の `premium` entitlement を購読する PurchaseManager から
// `proGateBridge` 経由で setIsPro(_:) が呼ばれる(後方互換 adapter)。

import Foundation
import Observation

@Observable
@MainActor
final class ProFeatureGate {
    /// Pro 購入済みかどうか。PurchaseManager.proGateBridge → `setIsPro(_:)` で更新される。
    /// View からは読み取り専用の感覚で扱うこと。
    var isPro: Bool = false

    /// EnvironmentKey.defaultValue から呼べるよう nonisolated にしておく。
    /// 状態 (isPro) には触れないので MainActor 隔離なしで安全。
    nonisolated init() {}

    /// 機能アクセス前のゲート。Paywall を出すかは UI 側が判断する。
    func check(_ feature: ProFeature) -> Bool {
        feature.isFreeTier || isPro
    }

    /// RevenueCat 由来の entitlement 状態更新を受ける唯一の入口。
    /// PurchaseManager の `proGateBridge` から `@MainActor` で呼ばれる。
    /// 直接 `isPro` を書き換えるのは禁止(NG リスト: ハードコード回避)。
    func setIsPro(_ value: Bool) {
        guard isPro != value else { return }
        isPro = value
    }

    /// テスト / プレビュー用に Pro 状態をセットする。
    /// 本番コードからは PurchaseManager 経由でしか変えない。
    func _setProForPreview(_ value: Bool) {
        isPro = value
    }
}
