// MARK: - ProFeature + Paywall display
// PaywallSections.swift から分離(CLAUDE.md「1 ファイル 300 行超で分割」)。
// Paywall リスト・バナー表示で使う localized 文字列。

import Foundation

extension ProFeature {

    /// Paywall の機能リストに出すタイトル文字列。
    var paywallTitle: String {
        switch self {
        case .unlimitedHistory:
            return String(localized: "paywall.feature.unlimited_history.title",
                          defaultValue: "全期間の履歴")
        case .advancedCharts:
            return String(localized: "paywall.feature.advanced_charts.title",
                          defaultValue: "詳細チャート")
        case .customTemplates:
            return String(localized: "paywall.feature.custom_templates.title",
                          defaultValue: "カスタムテンプレート無制限")
        case .csvImport:
            return String(localized: "paywall.feature.csv_import.title",
                          defaultValue: "CSV / JSON インポート")
        case .csvExport:
            return String(localized: "paywall.feature.csv_export.title",
                          defaultValue: "CSV エクスポート")
        case .manualEntry:
            return String(localized: "paywall.feature.manual_entry.title",
                          defaultValue: "手動ログ追加")
        case .customExercise:
            return String(localized: "paywall.feature.custom_exercise.title",
                          defaultValue: "種目のカスタム追加・編集")
        case .sessionPhoto:
            return String(localized: "paywall.feature.session_photo.title",
                          defaultValue: "セッション写真・メモ添付")
        case .appIconVariants:
            return String(localized: "paywall.feature.app_icon.title",
                          defaultValue: "App Icon バリエーション")
        case .watchOSCompanion:
            return String(localized: "paywall.feature.watch_companion.title",
                          defaultValue: "Apple Watch 連携 (v1.1+)")
        case .videoLink:
            return String(localized: "paywall.feature.video_link.title",
                          defaultValue: "YouTube 動画リンク")
        }
    }

    /// 機能リストの 1 行説明。
    var paywallDescription: String {
        switch self {
        case .unlimitedHistory:
            return String(localized: "paywall.feature.unlimited_history.desc",
                          defaultValue: "31 日以前のセッションを含めて全期間にアクセス。")
        case .advancedCharts:
            return String(localized: "paywall.feature.advanced_charts.desc",
                          defaultValue: "週次 / 月次ボリューム、部位別ヒートマップ。")
        case .customTemplates:
            return String(localized: "paywall.feature.custom_templates.desc",
                          defaultValue: "自分だけのワークアウトテンプレートを無制限に作成。")
        case .csvImport:
            return String(localized: "paywall.feature.csv_import.desc",
                          defaultValue: "他アプリ・workout-cool からの CSV / JSON 取り込み。")
        case .csvExport:
            return String(localized: "paywall.feature.csv_export.desc",
                          defaultValue: "履歴を CSV で書き出してバックアップ・分析に活用。")
        case .manualEntry:
            return String(localized: "paywall.feature.manual_entry.desc",
                          defaultValue: "アプリ外で実施した種目を後から記録。")
        case .customExercise:
            return String(localized: "paywall.feature.custom_exercise.desc",
                          defaultValue: "同梱種目に加えて自分だけの種目を追加・編集。")
        case .sessionPhoto:
            return String(localized: "paywall.feature.session_photo.desc",
                          defaultValue: "セッションに写真とメモを残す。")
        case .appIconVariants:
            return String(localized: "paywall.feature.app_icon.desc",
                          defaultValue: "ホーム画面のアイコンを切り替え。")
        case .watchOSCompanion:
            return String(localized: "paywall.feature.watch_companion.desc",
                          defaultValue: "v1.1 以降で順次提供予定。")
        case .videoLink:
            return String(localized: "paywall.feature.video_link.desc",
                          defaultValue: "種目詳細から YouTube アプリへのリンクを開く。")
        }
    }

    /// Paywall がどの導線で開かれたかを上部バナーで示す文言。
    var paywallReasonHeadline: String {
        switch self {
        case .unlimitedHistory:
            return String(localized: "paywall.reason.unlimited_history",
                          defaultValue: "31 日以前の履歴を見るには Pro が必要です。")
        case .advancedCharts:
            return String(localized: "paywall.reason.advanced_charts",
                          defaultValue: "詳細チャートは Pro 機能です。")
        case .customTemplates:
            return String(localized: "paywall.reason.custom_templates",
                          defaultValue: "カスタムテンプレートの作成は Pro 機能です。")
        case .csvImport:
            return String(localized: "paywall.reason.csv_import",
                          defaultValue: "CSV / JSON インポートは Pro 機能です。")
        case .csvExport:
            return String(localized: "paywall.reason.csv_export",
                          defaultValue: "CSV エクスポートは Pro 機能です。")
        case .manualEntry:
            return String(localized: "paywall.reason.manual_entry",
                          defaultValue: "手動ログ追加は Pro 機能です。")
        case .customExercise:
            return String(localized: "paywall.reason.custom_exercise",
                          defaultValue: "カスタム種目の追加・編集は Pro 機能です。")
        case .sessionPhoto:
            return String(localized: "paywall.reason.session_photo",
                          defaultValue: "セッションへの写真・メモ添付は Pro 機能です。")
        case .appIconVariants:
            return String(localized: "paywall.reason.app_icon",
                          defaultValue: "App Icon の変更は Pro 機能です。")
        case .watchOSCompanion:
            return String(localized: "paywall.reason.watch_companion",
                          defaultValue: "Apple Watch 連携は Pro 機能です。")
        case .videoLink:
            return String(localized: "paywall.reason.video_link",
                          defaultValue: "YouTube 動画リンクは Pro 機能です。")
        }
    }
}
