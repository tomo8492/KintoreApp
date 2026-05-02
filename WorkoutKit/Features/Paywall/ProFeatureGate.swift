// MARK: - ProFeatureGate
// CLAUDE.md §-1.14 準拠。Pro 判定は必ずこのクラス経由(NGリスト規約)。
// StoreKit 2 の Transaction.currentEntitlements を購読し isPro を更新する。
// 実体の StoreKit 連携は StoreKitClient(同フォルダ)が担当する。

import Foundation
import Observation

@Observable
@MainActor
final class ProFeatureGate {
    /// Pro 購入済みかどうか。StoreKitClient から `setIsPro(_:)` 経由で更新される。
    /// View からは読み取り専用の感覚で扱うこと。
    var isPro: Bool = false

    /// EnvironmentKey.defaultValue から呼べるよう nonisolated にしておく。
    /// 状態 (isPro) には触れないので MainActor 隔離なしで安全。
    nonisolated init() {}

    /// 機能アクセス前のゲート。Paywall を出すかは UI 側が判断する。
    func check(_ feature: ProFeature) -> Bool {
        feature.isFreeTier || isPro
    }

    /// StoreKit 由来の状態更新を受ける唯一の入口。
    /// actor (StoreKitClient) から `await` で呼ばれることを想定している。
    /// 直接 `isPro` を書き換えるのは禁止(NG リスト: ハードコード回避)。
    func setIsPro(_ value: Bool) {
        guard isPro != value else { return }
        isPro = value
    }

    /// テスト / プレビュー用に Pro 状態をセットする。
    /// 本番コードからは StoreKitClient 経由でしか変えない。
    func _setProForPreview(_ value: Bool) {
        isPro = value
    }
}
