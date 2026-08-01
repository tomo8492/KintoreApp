// MARK: - HistoryComponents
// CLAUDE.md §11.4 / §-1.14 準拠。
// HistoryView から切り出した小物 View と WorkoutSession の集計拡張。
// View 単独で意味を持たない補助コンポーネントだけを置く場所。

import SwiftUI

// MARK: - ProGateLockedView

/// 31 日以前のセッションが何らかの経路でナビに渡ってきた場合の保険として表示する。
/// 通常は HistoryView の handleSelect が PaywallTrigger で弾くため到達しない。
struct ProGateLockedView: View {
    let feature: ProFeature
    let onUnlock: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("history.locked.title", systemImage: "lock.fill")
        } description: {
            Text("history.locked.subtitle")
        } actions: {
            Button {
                onUnlock()
            } label: {
                Text("history.locked.unlock")
            }
            .buttonStyle(.primaryCTA)
        }
    }
}

// MARK: - HistorySessionRow (iPad sidebar)

/// iPad NavigationSplitView のサイドバーに並べる 1 セッション行。
struct HistorySessionRow: View {
    let session: WorkoutSession

    @AppStorage(SettingsKey.weightUnit) private var weightUnitRaw: String = WeightUnitPreference.kilograms.rawValue
    private var weightUnit: WeightUnitPreference {
        WeightUnitPreference(rawValue: weightUnitRaw) ?? .kilograms
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(UnitsFormatter.formatHistoryDate(session.startedAt))
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                Text(GoalLabels.displayName(for: session.goal))
                Text("•")
                Text(durationLabel)
                Text("•")
                Text(volumeLabel)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var durationLabel: String {
        guard let finished = session.finishedAt else { return "—" }
        let seconds = Int(finished.timeIntervalSince(session.startedAt))
        return UnitsFormatter.formatDuration(seconds: seconds)
    }

    private var volumeLabel: String {
        UnitsFormatter.formatWeight(session.totalVolumeKg, preference: weightUnit)
    }
}

// MARK: - WorkoutSession 集計拡張

extension WorkoutSession {
    /// 総ボリューム = Σ(reps × weightKg)。time-based セット(reps=0 / weight=0)は 0 寄与。
    var totalVolumeKg: Double {
        sets.reduce(0.0) { $0 + Double($1.reps) * $1.weightKg }
    }
}
