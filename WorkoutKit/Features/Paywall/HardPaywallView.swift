// MARK: - HardPaywallView
// CLAUDE.md v0.5 §-1.14 / §-1.1 準拠。
//
// サブスク前提のハードペイウォール。月額 / 年額の 2 プランを並べ、年額をデフォルト選択。
// 「年額の方が ¥1,860 お得」バッジを表示し、無料トライアル(7 日)を強調する。
//
// 表示タイミング(§-1.14):
//   1. 初回起動から 3 日経過後の起動時(LaunchTrialTracker から)
//   2. Pro 機能アクセス時(PaywallTrigger.gate 経由、既存仕様維持)
//
// 既存 `PaywallView`(v0.4 買い切り仕様)はマージ後の後続 PR で削除する想定。
// 本ファイルはサブスク移行用の新 View で、PurchaseManager を介して RevenueCat を呼ぶ。

import SwiftUI
import OSLog

@MainActor
struct HardPaywallView: View {

    /// 提示理由(任意。`.unlimitedHistory` 等のアクセストリガから渡る)。
    /// 起動時の強制表示では nil を渡す。
    let reason: ProFeature?

    /// 表示するプラン(`PurchaseManager.fetchOffering` から取得)。
    let offering: PurchaseOffering?

    /// 購入ボタン押下時に呼ばれる(View は actor を持たないので親 View が PurchaseManager に投げる)。
    let onPurchase: (PurchasePlan) -> Void
    let onRestore: () -> Void
    let onClose: () -> Void

    @State private var selectedPlanKind: PlanKind = .yearly
    @State private var isProcessing: Bool = false

    enum PlanKind { case monthly, yearly }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                featuresSection
                plansSection
                actionsSection
                footerSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .topTrailing) { closeButton }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("hard-paywall.title")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            if let reason {
                Text(reasonKey(for: reason))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("hard-paywall.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 40)
    }

    private func reasonKey(for feature: ProFeature) -> LocalizedStringKey {
        // 既存の paywall.reason.* キーが再利用可能。
        switch feature {
        case .unlimitedHistory: return "paywall.reason.unlimited_history"
        case .advancedCharts:   return "paywall.reason.advanced_charts"
        case .customTemplates:  return "paywall.reason.custom_templates"
        case .csvImport:        return "paywall.reason.csv_import"
        case .csvExport:        return "paywall.reason.csv_export"
        case .manualEntry:      return "paywall.reason.manual_entry"
        case .customExercise:   return "paywall.reason.custom_exercise"
        case .sessionPhoto:     return "paywall.reason.session_photo"
        case .appIconVariants:  return "paywall.reason.app_icon"
        case .watchOSCompanion: return "paywall.reason.watch_companion"
        case .videoLink:        return "paywall.reason.video_link"
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "clock.arrow.circlepath", titleKey: "hard-paywall.feature.history")
            featureRow(icon: "chart.bar.xaxis",        titleKey: "hard-paywall.feature.charts")
            featureRow(icon: "square.stack.3d.up",     titleKey: "hard-paywall.feature.templates")
            featureRow(icon: "square.and.arrow.down",  titleKey: "hard-paywall.feature.csv")
            featureRow(icon: "sparkles",               titleKey: "hard-paywall.feature.ai")
            featureRow(icon: "applewatch",             titleKey: "hard-paywall.feature.watch")
        }
        .padding(.horizontal, 8)
    }

    private func featureRow(icon: String, titleKey: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(titleKey)
                .font(.body)
            Spacer()
        }
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(spacing: 12) {
            planCard(
                kind: .yearly,
                titleKey: "hard-paywall.plan.yearly.title",
                priceText: offering?.yearly?.displayPrice ?? "¥4,900",
                subtitleKey: "hard-paywall.plan.yearly.subtitle",
                badgeKey: "hard-paywall.plan.yearly.badge",
                trialDays: offering?.yearly?.trialDays
            )
            planCard(
                kind: .monthly,
                titleKey: "hard-paywall.plan.monthly.title",
                priceText: offering?.monthly?.displayPrice ?? "¥980",
                subtitleKey: "hard-paywall.plan.monthly.subtitle",
                badgeKey: nil,
                trialDays: offering?.monthly?.trialDays
            )
        }
    }

    private func planCard(
        kind: PlanKind,
        titleKey: LocalizedStringKey,
        priceText: String,
        subtitleKey: LocalizedStringKey,
        badgeKey: LocalizedStringKey?,
        trialDays: Int?
    ) -> some View {
        let isSelected = selectedPlanKind == kind
        return Button {
            selectedPlanKind = kind
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(titleKey).font(.headline)
                        if let badgeKey {
                            Text(badgeKey)
                                .font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.accentColor, in: .capsule)
                                .foregroundStyle(.white)
                        }
                    }
                    Text(priceText)
                        .font(.title3.weight(.semibold))
                    Text(subtitleKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let trialDays, trialDays > 0 {
                        Text("hard-paywall.trial.days \(trialDays)")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                if let plan = currentlySelectedPlan {
                    isProcessing = true
                    onPurchase(plan)
                }
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView().controlSize(.small).tint(.white)
                    }
                    Text("hard-paywall.action.subscribe")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isProcessing || currentlySelectedPlan == nil)
            .accessibilityHint(Text("a11y.paywall.subscribe.hint"))

            Button(action: onRestore) {
                Text("hard-paywall.action.restore")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityHint(Text("a11y.paywall.restore.hint"))
        }
    }

    private var currentlySelectedPlan: PurchasePlan? {
        switch selectedPlanKind {
        case .yearly:  return offering?.yearly
        case .monthly: return offering?.monthly
        }
    }

    // MARK: - Footer / Close

    private var footerSection: some View {
        VStack(spacing: 6) {
            Text("hard-paywall.legal.disclaimer")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(12)
        }
        .accessibilityLabel(Text("common.close"))
    }
}
