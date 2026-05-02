// MARK: - PurchaseRestoring
// CLAUDE.md §-1.14 / Apple Guideline 3.1.1 準拠。
// Settings の Restore Purchase ボタンが呼び出す抽象。
// 実体は F1 StoreKitClient(別ブランチ)で実装され AppDependency 経由で差し替わる。
// このファイルだけでビルドが通るよう、デフォルトの no-op 実装を同梱する。

import Foundation

/// 購入復元(Restore Purchase)を担う抽象。
/// 復元成功時は ProFeatureGate.isPro が StoreKit のリスナー経由で
/// 更新される想定なので、戻り値ではエンタイトルメントの有無だけを返す。
protocol PurchaseRestoring: Sendable {
    /// 過去の購入履歴を Apple アカウントから取り直す。
    /// - Returns: 復元できた有効なエンタイトルメントが1件以上あれば `true`。
    /// - Throws: ネットワーク不通や StoreKit 内部エラー。ユーザー側のキャンセルは正常終了とする。
    @discardableResult
    func restorePurchases() async throws -> Bool
}

/// F1 StoreKitClient がまだ統合されていないビルドで使う既定実装。
/// 何もせず「復元なし」で返す。AppDependency.defaultValue から参照される。
struct NoopPurchaseRestorer: PurchaseRestoring {
    func restorePurchases() async throws -> Bool {
        false
    }
}
