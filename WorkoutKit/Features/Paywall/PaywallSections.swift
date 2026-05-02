// MARK: - PaywallSections
// PaywallView を分割するためのセクション View 群と ProFeature の表示用拡張。
// CLAUDE.md §-1.14 の Pro 機能境界に準拠して項目を列挙する。

import SwiftUI
import StoreKit

// MARK: - Header

struct PaywallHeader: View {
    let reason: ProFeature?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(String(localized: "paywall.title", defaultValue: "WorkoutKit Pro"))
                .font(.largeTitle.bold())

            Text(String(
                localized: "paywall.subtitle",
                defaultValue: "ワンタイム購入で全機能をロック解除。サブスクではありません。"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let reason {
                Text(reason.paywallReasonHeadline)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

// MARK: - Feature list

struct PaywallFeatureList: View {
    /// 起点となった機能。リスト中で強調マーカーを付ける。
    let highlight: ProFeature?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(
                localized: "paywall.features.title",
                defaultValue: "Pro で使える機能"
            ))
            .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(ProFeature.allCases, id: \.self) { feature in
                    PaywallFeatureRow(
                        feature: feature,
                        isHighlighted: feature == highlight
                    )
                }
            }
        }
    }
}

private struct PaywallFeatureRow: View {
    let feature: ProFeature
    let isHighlighted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(isHighlighted ? .tint : .secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.paywallTitle)
                    .font(.body)
                    .fontWeight(isHighlighted ? .semibold : .regular)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(feature.paywallDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isHighlighted ? [.isStaticText, .isHeader] : .isStaticText)
    }
}

// MARK: - Price section

struct PaywallPriceSection: View {
    /// StoreKit 2 から取得した Pro 商品。nil のときは loading 状態。
    let product: Product?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(
                localized: "paywall.price.title",
                defaultValue: "価格"
            ))
            .font(.headline)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let product {
                    Text(product.displayPrice)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(String(
                        localized: "paywall.price.one_time",
                        defaultValue: "買い切り"
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(String(
                            localized: "paywall.price.loading",
                            defaultValue: "価格を読み込み中…"
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Text(String(
                localized: "paywall.price.note",
                defaultValue: "App Store の家族共有に対応。一度購入すれば追加課金はありません。"
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Legal

struct PaywallLegalLinks: View {

    // TODO: 公開時に workoutkit.app の正式 URL に差し替える。
    // 現状は仕様書 §-1 で URL 未確定のためプレースホルダ。
    private static let termsURL = URL(string: "https://workoutkit.app/terms")
    private static let privacyURL = URL(string: "https://workoutkit.app/privacy")

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                if let termsURL = Self.termsURL {
                    Link(
                        String(localized: "paywall.legal.terms", defaultValue: "利用規約"),
                        destination: termsURL
                    )
                }
                if let privacyURL = Self.privacyURL {
                    Link(
                        String(localized: "paywall.legal.privacy", defaultValue: "プライバシーポリシー"),
                        destination: privacyURL
                    )
                }
            }
            .font(.footnote)

            Text(String(
                localized: "paywall.legal.disclaimer",
                defaultValue: "購入は Apple ID に紐づきます。返金・払い戻しは App Store の規定に従います。"
            ))
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - ProFeature display extensions

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
        }
    }
}
