// MARK: - PaywallTrigger
// CLAUDE.md §-1.14 のトリガー対応表 / §11.4 NG リスト準拠。
// Pro 機能アクセス箇所が Paywall 表示判定をするための共通ヘルパー。
//
// 利用例(後続タスクの View 側で):
// ```
// @Environment(\.appDependency) private var dep
// @State private var paywall: PaywallContext?
//
// var body: some View {
//     Button("31日以前の履歴を見る") {
//         PaywallTrigger.gate(.unlimitedHistory, proGate: dep.proGate, paywall: $paywall) {
//             // Pro 解放済み: 履歴画面に遷移するなど
//         }
//     }
//     .paywallSheet(paywall: $paywall)
// }
// ```
//
// 起動直後の自動表示は禁止(NG リスト)。必ず該当機能アクセス時のみ提示する。

import SwiftUI

// MARK: - PaywallContext

/// Paywall シートに渡す表示要因。
/// `Identifiable` にしておくと SwiftUI の `sheet(item:)` でそのまま使える。
struct PaywallContext: Identifiable, Hashable, Sendable {
    let feature: ProFeature
    var id: String { feature.rawValue }

    init(feature: ProFeature) {
        self.feature = feature
    }
}

// MARK: - PaywallTrigger

/// Pro 機能アクセス時のゲート処理を集約した名前空間。
/// View からは `PaywallTrigger.gate(...)` を呼ぶだけで Pro 判定 + Paywall 提示を行う。
@MainActor
enum PaywallTrigger {

    /// `feature` のロックが外れていれば `onAccess()` をその場で呼ぶ。
    /// ロック中なら `paywall` Binding に PaywallContext をセットして
    /// `paywallSheet(paywall:)` モディファイアにシート表示させる。
    ///
    /// - Parameters:
    ///   - feature: アクセスしたい Pro 機能。
    ///   - proGate: 環境から取得した ProFeatureGate(`appDependency.proGate`)。
    ///   - paywall: 呼び出し側 View の `@State private var paywall: PaywallContext?`。
    ///   - onAccess: Pro 解放済みのときに呼ばれるクロージャ。
    static func gate(
        _ feature: ProFeature,
        proGate: ProFeatureGate,
        paywall: Binding<PaywallContext?>,
        onAccess: () -> Void
    ) {
        if proGate.check(feature) {
            onAccess()
        } else {
            paywall.wrappedValue = PaywallContext(feature: feature)
        }
    }
}

// MARK: - View modifier

extension View {
    /// `paywall` Binding に PaywallContext が入った瞬間に PaywallView を sheet 表示する。
    /// 起動直後の Paywall を出すような使い方は禁止(NG リスト)。
    /// 呼び出し側は `PaywallTrigger.gate(...)` を経由して値を入れるだけにする。
    func paywallSheet(paywall: Binding<PaywallContext?>) -> some View {
        sheet(item: paywall) { context in
            PaywallView(reason: context.feature)
        }
    }
}
