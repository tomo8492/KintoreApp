// MARK: - ProPaywallPlaceholder
// CLAUDE.md §-1.14。本格 Paywall は Phase P5(StoreKit 2 実装時)。
// それまでは「Pro 機能」を伝えるシンプルなシートでプレースホルダ。
// §-1.14 の Paywall 表示タイミング(機能アクセス時にのみ出す)を満たす土台。

import SwiftUI

struct ProPaywallPlaceholder: View {
    let feature: ProFeature

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Pro feature")
                .font(.title2.weight(.semibold))
            Text("This feature requires WorkoutKit Pro.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Close") { dismiss() }
                .buttonStyle(.bordered)
                .padding(.top)
        }
        .padding()
    }
}
