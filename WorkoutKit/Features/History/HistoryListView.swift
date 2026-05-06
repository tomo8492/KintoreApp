// MARK: - HistoryListView
// CLAUDE.md §1.1 F-04 / §-1.14 / §11.4 準拠。
// セッション一覧モード。
// - 日付昇順 / 降順を切替可能
// - 日付ごとに Section でグループ化
// - 各セッションは「目的・所要時間・総ボリューム」を表示
// - 31 日以前にアクセスする経路は「Show all」ボタンで親 View にゲート要求を投げる
//   (PaywallTrigger.gate は親 View 側で動かす)

import SwiftUI

struct HistoryListView: View {

    enum SortOrder: String, CaseIterable, Identifiable {
        case newest, oldest
        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .newest: return "history.list.sort.newest"
            case .oldest: return "history.list.sort.oldest"
            }
        }
    }

    let sessions: [WorkoutSession]
    /// 31 日以前に finished なセッションが端末にあるか。Show all 行の表示条件に使う。
    let hasOlderSessions: Bool
    /// 親 View が ProFeatureGate を解放済みかどうか。true なら Show all 行は出さない。
    let showAllHistory: Bool
    let onSelect: (WorkoutSession) -> Void
    let onShowAllRequested: () -> Void

    /// 並び順は `@AppStorage` で永続化(セッション間で記憶)。
    /// rawValue は `SortOrder` の `"newest"` / `"oldest"`。未設定時は newest。
    @AppStorage(SettingsKey.historySortOrder) private var sortOrderRaw: String = SortOrder.newest.rawValue

    private var sortOrder: SortOrder {
        get { SortOrder(rawValue: sortOrderRaw) ?? .newest }
        nonmutating set { sortOrderRaw = newValue.rawValue }
    }

    /// Picker から SortOrder を直接 binding したいので AppStorage の文字列とブリッジする。
    private var sortOrderBinding: Binding<SortOrder> {
        Binding(
            get: { sortOrder },
            set: { sortOrderRaw = $0.rawValue }
        )
    }

    var body: some View {
        Group {
            if sessions.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        ContentUnavailableView {
            Label("history.empty.title", systemImage: "calendar.badge.clock")
        } description: {
            Text("history.empty.subtitle")
        }
    }

    // MARK: - List

    private var listContent: some View {
        List {
            sortPickerSection
            ForEach(groupedSessions, id: \.dayKey) { group in
                Section {
                    ForEach(group.sessions) { session in
                        Button {
                            onSelect(session)
                        } label: {
                            HistoryListRow(session: session)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(group.headerTitle)
                        .font(.subheadline.weight(.semibold))
                }
            }
            if !showAllHistory && hasOlderSessions {
                Section {
                    Button {
                        onShowAllRequested()
                    } label: {
                        Label("history.action.show-all", systemImage: "lock.fill")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .accessibilityLabel(Text("history.action.show-all"))
                    .accessibilityHint(Text("a11y.history.show-all.hint"))
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var sortPickerSection: some View {
        Section {
            Picker("history.list.sort", selection: sortOrderBinding) {
                ForEach(SortOrder.allCases) { order in
                    Text(order.titleKey).tag(order)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Grouping

    /// 同じ日(ローカルカレンダー基準)のセッションをまとめた表示用構造体。
    private struct DayGroup {
        let dayKey: Date
        let sessions: [WorkoutSession]
        let headerTitle: String
    }

    private var groupedSessions: [DayGroup] {
        // 日付境界はユーザー TimeZone 追従の calendar で計算する (DEBUG_REPORT Critical-3)。
        let calendar = HistoryCutoff.defaultCalendar
        let dict = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startedAt) }
        let keys = dict.keys.sorted(by: { sortOrder == .newest ? $0 > $1 : $0 < $1 })
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = .current
            f.dateStyle = .full
            f.timeStyle = .none
            return f
        }()
        return keys.map { key in
            let dayItems = (dict[key] ?? [])
                .sorted { sortOrder == .newest ? $0.startedAt > $1.startedAt : $0.startedAt < $1.startedAt }
            return DayGroup(
                dayKey: key,
                sessions: dayItems,
                headerTitle: formatter.string(from: key)
            )
        }
    }
}

// MARK: - Row

private struct HistoryListRow: View {
    let session: WorkoutSession

    @AppStorage(SettingsKey.weightUnit) private var weightUnitRaw: String = WeightUnitPreference.kilograms.rawValue
    private var weightUnit: WeightUnitPreference {
        WeightUnitPreference(rawValue: weightUnitRaw) ?? .kilograms
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeOfDay)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(session.goal.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 76, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Label {
                        Text(durationLabel)
                    } icon: {
                        Image(systemName: "clock")
                    }
                    Label {
                        Text(volumeLabel)
                    } icon: {
                        Image(systemName: "scalemass")
                    }
                }
                .font(.subheadline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                Text(setsLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(timeOfDay), \(session.goal.rawValue)"))
        .accessibilityValue(Text("\(durationLabel), \(volumeLabel), \(setsLabel)"))
    }

    private var timeOfDay: String {
        let f = DateFormatter()
        f.locale = .current
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: session.startedAt)
    }

    private var durationLabel: String {
        guard let finished = session.finishedAt else {
            return String(localized: "history.row.in-progress", defaultValue: "—")
        }
        let seconds = Int(finished.timeIntervalSince(session.startedAt))
        return UnitsFormatter.formatDuration(seconds: seconds)
    }

    private var volumeLabel: String {
        let total = session.totalVolumeKg
        return UnitsFormatter.formatWeight(total, preference: weightUnit)
    }

    private var setsLabel: String {
        let count = session.sets.count
        let template = String(
            localized: "history.row.sets",
            defaultValue: "%lld セット"
        )
        return String(format: template, count)
    }
}

#Preview {
    HistoryListView(
        sessions: [],
        hasOlderSessions: true,
        showAllHistory: false,
        onSelect: { _ in },
        onShowAllRequested: {}
    )
}
