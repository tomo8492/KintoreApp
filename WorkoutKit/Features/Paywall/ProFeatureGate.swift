// MARK: - ProFeatureGate
// CLAUDE.md §-1.14 準拠。Pro 判定は必ずこのクラス経由(NGリスト規約)。
// StoreKit 2 の Transaction.currentEntitlements を購読し isPro を更新する。
// 実際の StoreKit 連携は Phase P5 で StoreKitClient から差し込む。

import Foundation
import Observation

@Observable
@MainActor
final class ProFeatureGate {
    /// Pro 購入済みかどうか。StoreKit 2 が更新する。
    var isPro: Bool = false

    /// EnvironmentKey.defaultValue から呼べるよう nonisolated にしておく。
    /// 状態 (isPro) には触れないので MainActor 隔離なしで安全。
    nonisolated init() {}

    /// 機能アクセス前のゲート。Paywall を出すかは UI 側が判断する。
    func check(_ feature: ProFeature) -> Bool {
        feature.isFreeTier || isPro
    }

    /// テスト / プレビュー用に Pro 状態をセットする。
    /// 本番コードからは StoreKit 経由でしか変えない。
    func _setProForPreview(_ value: Bool) {
        isPro = value
    }
}
