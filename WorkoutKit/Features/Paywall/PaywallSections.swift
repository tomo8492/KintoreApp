// MARK: - PaywallSections
// PaywallView を分割するためのセクション View 群。
// CLAUDE.md §-1.14 の Pro 機能境界に準拠。
//
// ファイル分割(CLAUDE.md「1 ファイル 300 行超で分割」):
//   - 本ファイル: Header / FeatureList / PriceSection
//   - PaywallLegalSection.swift: PaywallLegalLinks(本番 URL 差替必須)
//   - ProFeature+Paywall.swift: ProFeature 表示用 extension(title / desc / reason)

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

    private var visibleFeatures: [ProFeature] {
        ProFeature.allCases.filter(\.isShownInPaywallV1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(
                localized: "paywall.features.title",
                defaultValue: "Pro で使える機能"
            ))
            .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                // v1.0 では `isShownInPaywallV1` で v1.1+ ロードマップ機能を除外する
                // (customExercise / sessionPhoto / appIconVariants)。
                // 詳細は ProFeature.swift と docs/ROADMAP.md。
                ForEach(visibleFeatures, id: \.self) { feature in
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
                .foregroundStyle(isHighlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
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
