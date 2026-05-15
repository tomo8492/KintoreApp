// MARK: - PaywallView
// CLAUDE.md v1.0 §6-6 準拠。
//
// サブスク前提のハードペイウォール。月額 / 年額の 2 プランを並べ、年額をデフォルト選択。
// 「月額より ¥7,372 お得」バッジ + 7 日無料トライアルを強調する。
//
// 表示タイミング(§6-5):
//   1. 初回起動から 3 日経過後の起動時(LaunchTrialTracker から)
//   2. プレミアム機能アクセス時(PaywallTrigger.gate 経由)
//   3. Settings → プレミアムにアップグレード タップ時
//
// 既存呼び出し元の互換性:
//   - `PaywallView(reason: feature)` の 1 引数シグネチャを維持(TemplatesView /
//     PaywallTrigger から既存通り呼べる)
//   - PurchaseManager は AppDependency 経由で取得し、Offering / 購入 / 復元 /
//     isPremium を読み書きする。
//   - 旧 v0.4 PaywallView(StoreKitClient ベース)は本ファイルで上書きされた。

import SwiftUI
import OSLog

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
                    Text(priceText).font(.title3.weight(.semibold))
                    Text(subtitleKey).font(.caption).foregroundStyle(.secondary)
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
                Task { await runPurchase() }
            } label: {
                HStack {
                    if status == .purchasing {
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
            .disabled(status != .idle || currentlySelectedPlan == nil)
            .accessibilityHint(Text("a11y.paywall.subscribe.hint"))

            Button {
                Task { await runRestore() }
            } label: {
                HStack(spacing: 8) {
                    if status == .restoring {
                        ProgressView().controlSize(.small)
                    }
                    Text("hard-paywall.action.restore").font(.subheadline)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(status != .idle)
            .accessibilityHint(Text("a11y.paywall.restore.hint"))
        }
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
    /// `var purchaseManager: PurchaseManager` を AppDependency に追加するのは
    /// 後続コミットで行うが、ここでは `dependency.purchaseManager` の前提で書く
    /// (Mac 側で AppDependency を埋めるまで未配線エラーが出る)。
    private var offering: PurchaseOffering? {
        dependency.purchaseManager.offering
    }

    private var currentlySelectedPlan: PurchasePlan? {
        switch selectedPlanKind {
        case .yearly:  return offering?.yearly
        case .monthly: return offering?.monthly
        }
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
            case .success:   dismiss()
            case .cancelled: break
            case .pending:
                statusMessage = String(localized: "paywall.purchase.pending")
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func runRestore() async {
        status = .restoring
        defer { status = .idle }
        do {
            let restored = try await dependency.purchaseManager.restore()
            if restored {
                dismiss()
            } else {
                statusMessage = String(localized: "paywall.restore.no_purchase")
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
