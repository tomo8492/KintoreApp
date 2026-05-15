// MARK: - PurchaseRestoring
// CLAUDE.md §-1.14 / Apple Guideline 3.1.1 準拠。
// Settings の Restore Purchase ボタンが呼び出す抽象。
// v1.0 本番実装は PurchaseManager(RevenueCat 経由)。Preview / 単体テスト用に
// no-op の既定実装も同梱する。

import Foundation

/// 購入復元(Restore Purchase)を担う抽象。
/// 復元成功時は ProFeatureGate.isPro が PurchaseManager.proGateBridge 経由で
/// 更新されるので、戻り値ではエンタイトルメントの有無だけを返す。
protocol PurchaseRestoring: Sendable {
    /// 過去の購入履歴を Apple アカウントから取り直す。
    /// - Returns: 復元できた有効なエンタイトルメントが1件以上あれば `true`。
    /// - Throws: ネットワーク不通や StoreKit 内部エラー。ユーザー側のキャンセルは正常終了とする。
    @discardableResult
    func restorePurchases() async throws -> Bool
}

/// Preview / 単体テスト用の既定実装。何もせず「復元なし」で返す。
/// 本番経路では PurchaseManager.shared が PurchaseRestoring に適合している。
struct NoopPurchaseRestorer: PurchaseRestoring {
    func restorePurchases() async throws -> Bool {
        false
    }
}
