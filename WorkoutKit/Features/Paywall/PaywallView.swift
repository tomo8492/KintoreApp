// MARK: - PaywallView
// CLAUDE.md §-1.14 / §11.4 準拠。
// - StoreKitClient(actor)から商品情報を読み出し displayPrice を表示
// - 購入 / 復元ボタンは StoreKitClient.purchase() / restorePurchases() を呼ぶだけ
// - 利用規約・プライバシーポリシーへのリンクを表示
// - 起動直後の自動表示は禁止(呼び出し元 View の PaywallTrigger.gate 経由でのみ提示)

import SwiftUI
import StoreKit

// MARK: - PaywallView

@MainActor
struct PaywallView: View {

    /// なぜこの Paywall が出ているか。リスト先頭に「← この機能」マーカーを出すために使う。
    let reason: ProFeature?

    @Environment(\.appDependency) private var dependency
    @Environment(\.dismiss) private var dismiss

    @State private var product: Product?
    @State private var status: Status = .idle

    enum Status: Equatable {
        case idle
        case purchasing
        case restoring
        case info(message: String)
        case error(message: String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    PaywallHeader(reason: reason)
                    PaywallFeatureList(highlight: reason)
                    PaywallPriceSection(product: product)
                    actionButtons
                    statusBanner
                    PaywallLegalLinks()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(Text(String(localized: "paywall.nav.title", defaultValue: "Pro")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .accessibilityLabel(Text(String(
                                localized: "paywall.action.close",
                                defaultValue: "閉じる"
                            )))
                    }
                }
            }
            .task {
                await loadProduct()
            }
        }
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task { await runPurchase() }
            } label: {
                Text(purchaseLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(product == nil || status == .purchasing || status == .restoring)

            Button {
                Task { await runRestore() }
            } label: {
                Text(restoreLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(status == .purchasing || status == .restoring)
        }
    }

    private var purchaseLabel: String {
        if status == .purchasing {
            return String(localized: "paywall.action.purchasing", defaultValue: "処理中…")
        }
        return String(localized: "paywall.action.purchase", defaultValue: "Pro を購入")
    }

    private var restoreLabel: String {
        if status == .restoring {
            return String(localized: "paywall.action.restoring", defaultValue: "復元中…")
        }
        return String(localized: "paywall.action.restore", defaultValue: "購入を復元")
    }

    // MARK: - Status banner

    @ViewBuilder
    private var statusBanner: some View {
        switch status {
        case .info(let message):
            Label(message, systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        default:
            EmptyView()
        }
    }

    // MARK: - Product / Purchase / Restore

    private func loadProduct() async {
        product = await dependency.storeKitClient.cachedProduct
        if product == nil {
            // start() が走っていれば cachedProduct が入る。レース対策で 1 回再試行はせず、
            // UI 側は loading / unavailable を出すだけにする(F1 が起動時に refresh 済み)。
            Logger.store.info("PaywallView: product not yet loaded")
        }
    }

    private func runPurchase() async {
        guard product != nil else {
            status = .error(message: String(
                localized: "paywall.price.unavailable",
                defaultValue: "価格を取得できませんでした。後でもう一度お試しください。"
            ))
            return
        }
        status = .purchasing
        do {
            let result = try await dependency.storeKitClient.purchase()
            handlePurchaseResult(result)
        } catch {
            Logger.store.error("PaywallView purchase error: \(error.localizedDescription, privacy: .public)")
            status = .error(message: String(
                localized: "paywall.purchase.failed",
                defaultValue: "購入処理に失敗しました。時間をおいて再試行してください。"
            ))
        }
    }

    private func handlePurchaseResult(_ result: PurchaseResult) {
        switch result {
        case .success:
            // ProFeatureGate.isPro は StoreKitClient 内で更新済み。シートを閉じる。
            dismiss()
        case .userCancelled:
            status = .info(message: String(
                localized: "paywall.purchase.cancelled",
                defaultValue: "購入はキャンセルされました。"
            ))
        case .pending:
            status = .info(message: String(
                localized: "paywall.purchase.pending",
                defaultValue: "購入は保留中です。承認後に自動的に反映されます。"
            ))
        case .verificationFailed, .unknown:
            status = .error(message: String(
                localized: "paywall.purchase.verification_failed",
                defaultValue: "レシートの検証に失敗しました。サポートまでお問い合わせください。"
            ))
        }
    }

    private func runRestore() async {
        status = .restoring
        do {
            try await dependency.storeKitClient.restorePurchases()
        } catch {
            Logger.store.error("PaywallView restore error: \(error.localizedDescription, privacy: .public)")
            status = .error(message: String(
                localized: "paywall.restore.failed",
                defaultValue: "復元に失敗しました。Apple ID に接続できているか確認してください。"
            ))
            return
        }
        if dependency.proGate.isPro {
            dismiss()
        } else {
            status = .info(message: String(
                localized: "paywall.restore.no_purchase",
                defaultValue: "復元できる購入が見つかりませんでした。"
            ))
        }
    }
}

#Preview("Default (no reason)") {
    PaywallView(reason: nil)
}

#Preview("From Unlimited History") {
    PaywallView(reason: .unlimitedHistory)
}
