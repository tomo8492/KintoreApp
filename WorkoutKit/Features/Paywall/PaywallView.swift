// MARK: - PaywallView
// CLAUDE.md v1.0 §6-6 準拠。
//
// サブスク前提のハードペイウォール。月額 / 年額の 2 プランを並べ、年額をデフォルト選択。
// 「月額より ¥3,260 お得」バッジ + 7 日無料トライアルを強調する。
//
// 2026 UX ベストプラクティス(RevenueCat + Adapty + Apple HIG 統合):
//   - Visual Trial Timeline(Apple-endorsed): 今日 / 5 日目リマインダー / 7 日目課金
//   - Price anchoring: 年額に「月あたり ¥408」「40% OFF」を併記
//   - Dynamic CTA copy: トライアル有なら「7 日間 無料で始める」、無なら「プレミアムに登録」
//   - Haptic feedback: プラン選択時の `.selection` フィードバック
//   - Cancel anytime trust signal: plan subtitle に明示
//
// 表示タイミング(§6-5):
//   1. 初回起動から 3 日経過後の起動時(LaunchTrialTracker から)
//   2. プレミアム機能アクセス時(PaywallTrigger.gate 経由)
//   3. Settings → プレミアムにアップグレード タップ時
//
// 既存呼び出し元の互換性:
//   - `PaywallView(reason: feature)` の 1 引数シグネチャを維持
//   - PurchaseManager は AppDependency 経由で取得し、Offering / 購入 / 復元 /
//     isPremium を読み書きする。

import SwiftUI
import OSLog
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct PaywallView: View {

    /// なぜこの Paywall が出ているか。reason 行の表示に使う。
    let reason: ProFeature?

    @Environment(\.appDependency) private var dependency
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlanKind: PlanKind = .yearly
    @State private var status: Status = .idle
    @State private var statusMessage: String?

    enum PlanKind { case monthly, yearly }
    enum Status: Equatable { case idle, purchasing, restoring }

    /// 年額の割引率(¥680×12 = ¥8,160 → ¥4,900 で約 39.9% OFF)。
    /// Localizable に %lld で渡す。
    private static let yearlyPercentOff: Int = 40

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                featuresSection
                plansSection
                trialTimelineSection
                actionsSection
                footerSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .topTrailing) { closeButton }
        .task { await loadOffering() }
        .alert(
            "paywall.alert.title",
            isPresented: alertBinding,
            actions: { Button("common.ok", role: .cancel) {} },
            message: { Text(statusMessage ?? "") }
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.bounce, options: .nonRepeating, value: status)
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

    // MARK: - Features list

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "sparkles",               titleKey: "hard-paywall.feature.ai")
            featureRow(icon: "clock.arrow.circlepath", titleKey: "hard-paywall.feature.history")
            featureRow(icon: "chart.bar.xaxis",        titleKey: "hard-paywall.feature.charts")
            featureRow(icon: "square.stack.3d.up",     titleKey: "hard-paywall.feature.templates")
            featureRow(icon: "square.and.arrow.down",  titleKey: "hard-paywall.feature.csv")
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
            Text(titleKey).font(.body)
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
                trialDays: offering?.yearly?.trialDays,
                isYearly: true
            )
            planCard(
                kind: .monthly,
                titleKey: "hard-paywall.plan.monthly.title",
                priceText: offering?.monthly?.displayPrice ?? "¥680",
                subtitleKey: "hard-paywall.plan.monthly.subtitle",
                badgeKey: nil,
                trialDays: offering?.monthly?.trialDays,
                isYearly: false
            )
        }
    }

    private func planCard(
        kind: PlanKind,
        titleKey: LocalizedStringKey,
        priceText: String,
        subtitleKey: LocalizedStringKey,
        badgeKey: LocalizedStringKey?,
        trialDays: Int?,
        isYearly: Bool
    ) -> some View {
        let isSelected = selectedPlanKind == kind
        return Button {
            // 2026 UX: 触覚フィードバックでプラン切替を体感的に伝える。
            // `.selection` は柔らかい tick。`.success` だと購入完了と混同するので避ける。
            #if os(iOS)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif
            selectedPlanKind = kind
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(titleKey).font(.headline)
                        if let badgeKey {
                            Text(badgeKey)
                                .font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.accentColor, in: .capsule)
                                .foregroundStyle(.white)
                        }
                        // 年額には「% OFF」も併記(price anchoring 強化、Adapty 2026)。
                        if isYearly {
                            Text("hard-paywall.plan.yearly.percent-off \(Self.yearlyPercentOff)")
                                .font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(AppColor.success.opacity(0.85), in: .capsule)
                                .foregroundStyle(.white)
                        }
                    }
                    Text(priceText).font(.title3.weight(.semibold))
                    // 年額のみ「月あたり ¥408」を併記する(月額との比較を直感化)。
                    if isYearly, let monthlyEquivalent = monthlyEquivalentText(from: priceText) {
                        Text("hard-paywall.plan.yearly.monthly-equivalent \(monthlyEquivalent)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(subtitleKey).font(.caption).foregroundStyle(.secondary)
                    if let trialDays, trialDays > 0 {
                        Label("hard-paywall.trial.days \(trialDays)", systemImage: "gift.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .fill(Color.secondary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Visual Trial Timeline (Apple-endorsed 2026 pattern)

    /// 「今日 → 5 日目リマインダー → 7 日目課金開始」を 3 ステップで可視化する。
    /// Apple 公式ガイドラインで 2025 末から推奨されている trust building UI。
    /// トライアル付きプランが選ばれていて、トライアル日数が取得できているときのみ表示。
    @ViewBuilder
    private var trialTimelineSection: some View {
        if let plan = currentlySelectedPlan, let trialDays = plan.trialDays, trialDays > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text("hard-paywall.timeline.title")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    timelineStep(
                        icon: "checkmark.circle.fill",
                        accent: .green,
                        titleKey: "hard-paywall.timeline.step1.title",
                        bodyKey: "hard-paywall.timeline.step1.body",
                        showConnector: true
                    )
                    timelineStep(
                        icon: "bell.fill",
                        accent: .orange,
                        titleKey: "hard-paywall.timeline.step2.title",
                        bodyKey: "hard-paywall.timeline.step2.body",
                        showConnector: true
                    )
                    timelineStepDynamic(
                        icon: "creditcard.fill",
                        accent: .accentColor,
                        trialDays: trialDays,
                        bodyKey: "hard-paywall.timeline.step3.body",
                        showConnector: false
                    )
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                        .fill(Color.secondary.opacity(0.06))
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("hard-paywall.timeline.title"))
        }
    }

    private func timelineStep(
        icon: String,
        accent: Color,
        titleKey: LocalizedStringKey,
        bodyKey: LocalizedStringKey,
        showConnector: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundStyle(accent)
                }
                if showConnector {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(titleKey)
                    .font(.subheadline.bold())
                Text(bodyKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, showConnector ? 12 : 0)
            Spacer()
        }
    }

    /// Step 3 は日数を動的に埋め込む必要があるので、別関数で LocalizationValue を使う。
    private func timelineStepDynamic(
        icon: String,
        accent: Color,
        trialDays: Int,
        bodyKey: LocalizedStringKey,
        showConnector: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundStyle(accent)
                }
            }
            .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("hard-paywall.timeline.step3.title \(trialDays)")
                    .font(.subheadline.bold())
                Text(bodyKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                Task { await runPurchase() }
            } label: {
                HStack {
                    if status == .purchasing {
                        ProgressView().controlSize(.small).tint(.white)
                    }
                    Text(ctaLabelKey)
                }
            }
            .buttonStyle(.primaryCTA)
            .disabled(status != .idle || currentlySelectedPlan == nil)
            .accessibilityHint(Text("a11y.paywall.subscribe.hint"))

            Button {
                Task { await runRestore() }
            } label: {
                HStack(spacing: 8) {
                    if status == .restoring {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                    }
                    Text("hard-paywall.action.restore").font(.subheadline)
                }
                .frame(maxWidth: .infinity, minHeight: 44) // タップターゲット 44pt 確保
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(status != .idle)
            .accessibilityHint(Text("a11y.paywall.restore.hint"))
        }
    }

    /// 選択中プランのトライアル有無で CTA を動的に切替。
    /// RevenueCat 2026 ベンチマーク: 「Continue」より具体的な「Start free trial」が
    /// trial-to-paid +31%、トライアル無の場合は「Subscribe」明示で誤タップ防止。
    private var ctaLabelKey: LocalizedStringKey {
        if let trialDays = currentlySelectedPlan?.trialDays, trialDays > 0 {
            return "hard-paywall.action.start-trial \(trialDays)"
        }
        return "hard-paywall.action.subscribe-now"
    }

    private var footerSection: some View {
        Text("hard-paywall.legal.disclaimer")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(12)
        }
        .accessibilityLabel(Text("common.close"))
    }

    // MARK: - Derived state

    /// AppDependency 経由で PurchaseManager.shared が注入されている前提。
    private var offering: PurchaseOffering? {
        dependency.purchaseManager.offering
    }

    private var currentlySelectedPlan: PurchasePlan? {
        switch selectedPlanKind {
        case .yearly:  return offering?.yearly
        case .monthly: return offering?.monthly
        }
    }

    /// 年額表示価格(例: "¥4,900")から月あたり換算文字列(例: "¥408")を生成。
    /// ロケール記号や桁区切りを保つため、数値部分だけ抜き出して 12 で割る。
    /// 抽出失敗時は nil を返して併記表示を諦める(安全側)。
    private func monthlyEquivalentText(from yearlyPriceText: String) -> String? {
        let digits = yearlyPriceText.filter { $0.isNumber }
        guard let yearly = Int(digits), yearly > 0 else { return nil }
        let monthly = Int((Double(yearly) / 12.0).rounded())
        // 通貨記号と区切り文字をローカライズして再構築する。
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        // ¥/$/€ 等は yearlyPriceText の prefix を引き継ぐのが最も自然。
        // (ロケール推測に失敗しても元の通貨を保てる)
        let prefix = yearlyPriceText.prefix { !$0.isNumber }
        formatter.currencySymbol = String(prefix)
        if let formatted = formatter.string(from: NSNumber(value: monthly)) {
            return formatted
        }
        return "\(prefix)\(monthly)"
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )
    }

    // MARK: - Actions

    private func loadOffering() async {
        do {
            _ = try await dependency.purchaseManager.fetchOffering()
        } catch {
            Logger.store.warning("fetchOffering failed: \(error.localizedDescription, privacy: .public)")
            statusMessage = error.localizedDescription
        }
    }

    private func runPurchase() async {
        guard let plan = currentlySelectedPlan else { return }
        status = .purchasing
        defer { status = .idle }
        do {
            let outcome = try await dependency.purchaseManager.purchase(plan: plan)
            switch outcome {
            case .success:
                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
                dismiss()
            case .cancelled: break
            case .pending:
                statusMessage = String(localized: "paywall.purchase.pending")
            }
        } catch {
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
            statusMessage = error.localizedDescription
        }
    }

    private func runRestore() async {
        status = .restoring
        defer { status = .idle }
        do {
            let restored = try await dependency.purchaseManager.restore()
            if restored {
                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
                dismiss()
            } else {
                statusMessage = String(localized: "paywall.restore.no_purchase")
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
