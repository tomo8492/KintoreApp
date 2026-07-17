// MARK: - ProFeature
// CLAUDE.md §-1.14 の Pro 機能境界を列挙する。
// Pro 判定は必ず ProFeatureGate.check(_:) 経由で行うこと(NGリスト参照)。

import Foundation

enum ProFeature: String, CaseIterable, Sendable {

    // MARK: v1.0 — UI gate 実装済み・App Store description に掲載
    case unlimitedHistory   // 履歴 31日以前
    case advancedCharts     // 週次/月次ボリューム、部位別ヒートマップ
    case customTemplates    // カスタムテンプレート無制限(create / duplicate / delete)
    case csvImport          // CSV/JSON インポート
    case csvExport          // 履歴エクスポート
    case manualEntry        // F-04 アプリ外ログ追加(Issue #88)
    case videoLink          // YouTube Deep Link(F-02 詳細画面)

    // MARK: v1.1+ Roadmap — enum case は残し、UI gate と App Store 掲載は v1.1 で追加
    // 詳細は docs/ROADMAP.md。
    case customExercise     // v1.1: ユーザー作成種目の管理 UI(Library 内 Add/Edit)
    case sessionPhoto       // v1.1: セッション写真添付(WorkoutSession に attachment 追加)
    case appIconVariants    // v1.1: 代替アイコン(Assets に AlternateAppIcon を追加)

    // MARK: v1.1+ Roadmap — description で "(v1.1+)" 明示済み
    case watchOSCompanion   // v1.1+: Apple Watch 連携
}

extension ProFeature {
    /// 今のところ全て Pro 限定。将来 freemium 切り出しが発生したらここで分岐する。
    var isFreeTier: Bool { false }
}
