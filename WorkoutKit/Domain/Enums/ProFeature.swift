// MARK: - ProFeature
// CLAUDE.md §-1.14 の Pro 機能境界を列挙する。
// Pro 判定は必ず ProFeatureGate.check(_:) 経由で行うこと(NGリスト参照)。

import Foundation

enum ProFeature: String, CaseIterable, Sendable {
    case unlimitedHistory   // 履歴 31日以前
    case advancedCharts     // 週次/月次ボリューム、部位別ヒートマップ
    case customTemplates    // カスタムテンプレート無制限
    case csvImport          // CSV/JSON インポート
    case csvExport          // 履歴エクスポート
    case manualEntry        // F-04 アプリ外ログ追加(Issue #88)
    case customExercise     // 種目のカスタム追加・編集
    case sessionPhoto       // セッションへの写真・メモ添付
    case appIconVariants    // App Icon 変更
    case watchOSCompanion   // Apple Watch 連携(v1.1+)
}

extension ProFeature {
    /// 今のところ全て Pro 限定。将来 freemium 切り出しが発生したらここで分岐する。
    var isFreeTier: Bool { false }
}
