// MARK: - HistorySessionDetailView
// CLAUDE.md §1.1 F-04 / §-1.4 / §11.4 準拠。
// 1 セッション分の詳細。
// - ヘッダ: 日時 / 目的 / 所要時間 / 総ボリューム
// - 種目別: 各 Exercise ごとに合計セット数・合計ボリュームを表示
// - 各セット内訳: reps × weight(kg)、RPE、休憩、完了時刻
// - notes 表示。編集機能は v1.1+(F-04 Issue #88 で manualEntry 連携時)に持ち越す

import SwiftUI

struct HistorySessionDetailView: View {
    let session: WorkoutSession

    @AppStorage(SettingsKey.weightUnit) private var weightUnitRaw: String = WeightUnitPreference.kilograms.rawValue
    private var weightUnit: WeightUnitPreference {
        WeightUnitPreference(rawValue: weightUnitRaw) ?? .kilograms
    }

    var body: some View {
        List {
            headerSection
            ForEach(exerciseGroups, id: \.slug) { group in
                Section(group.displayName) {
                    exerciseSummary(group)
                    ForEach(group.sets) { set in
                        SetRow(set: set, index: index(of: set, in: group), weightUnit: weightUnit)
                    }
                }
            }
            if !session.notes.isEmpty {
                Section("history.detail.notes") {
                    Text(session.notes)
                        .font(.body)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("history.detail.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(UnitsFormatter.formatHistoryDate(session.startedAt))
                    .font(.headline)
                HStack(spacing: 16) {
                    metaItem(icon: "target", value: session.goal.rawValue)
                    metaItem(icon: "clock", value: durationLabel)
                    metaItem(icon: "scalemass", value: volumeLabel)
                }
                .font(.subheadline.monospacedDigit())
                if session.isManualEntry {
                    Label("history.detail.manual-entry", systemImage: "square.and.pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func metaItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(value)
        }
        .foregroundStyle(.secondary)
    }

    private var durationLabel: String {
        guard let finished = session.finishedAt else {
            return String(localized: "history.row.in-progress", defaultValue: "—")
        }
        let seconds = Int(finished.timeIntervalSince(session.startedAt))
        return UnitsFormatter.formatDuration(seconds: seconds)
    }

    private var volumeLabel: String {
        UnitsFormatter.formatWeight(session.totalVolumeKg, preference: weightUnit)
    }

    // MARK: - Exercise summary row

    private func exerciseSummary(_ group: ExerciseGroup) -> some View {
        let setCount = group.sets.count
        let setsTemplate = String(
            localized: "history.detail.exercise.summary.sets",
            defaultValue: "%lld セット"
        )
        let totalVolume = UnitsFormatter.formatWeight(group.totalVolumeKg, preference: weightUnit)
        return HStack {
            Text(String(format: setsTemplate, setCount))
            Spacer()
            Text(totalVolume)
                .monospacedDigit()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    // MARK: - Grouping

    /// セッション内のセットを Exercise.slug でグループ化。順序は order の最小値で決定。
    private struct ExerciseGroup {
        let slug: String
        let displayName: String
        let sets: [ExerciseSet]
        let totalVolumeKg: Double
    }

    private var exerciseGroups: [ExerciseGroup] {
        let sorted = session.sets.sorted { $0.order < $1.order }
        var seen: [String] = []
        var bucket: [String: [ExerciseSet]] = [:]
        var nameMap: [String: String] = [:]

        for set in sorted {
            // 種目が消えた場合(SwiftData リレーション欠損)は表示用 placeholder。
            let slug = set.exercise?.slug ?? "missing"
            if bucket[slug] == nil {
                seen.append(slug)
            }
            bucket[slug, default: []].append(set)
            if nameMap[slug] == nil {
                nameMap[slug] = set.exercise?.nameJa
                    ?? set.exercise?.nameEn
                    ?? String(localized: "history.detail.unknown-exercise",
                              defaultValue: "(削除された種目)")
            }
        }

        return seen.map { slug in
            let sets = bucket[slug] ?? []
            let total = sets.reduce(0.0) { $0 + Double($1.reps) * $1.weightKg }
            return ExerciseGroup(
                slug: slug,
                displayName: nameMap[slug] ?? slug,
                sets: sets,
                totalVolumeKg: total
            )
        }
    }

    private func index(of set: ExerciseSet, in group: ExerciseGroup) -> Int {
        (group.sets.firstIndex { $0.id == set.id } ?? 0) + 1
    }
}

// MARK: - SetRow

private struct SetRow: View {
    let set: ExerciseSet
    let index: Int
    let weightUnit: WeightUnitPreference

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%d", index))
                .font(.caption.weight(.semibold).monospacedDigit())
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                primaryLine
                secondaryLine
            }
            Spacer(minLength: 0)
        }
        .font(.subheadline.monospacedDigit())
    }

    private var primaryLine: some View {
        HStack(spacing: 8) {
            if let duration = set.durationSeconds, duration > 0 {
                Label {
                    Text(UnitsFormatter.formatDuration(seconds: duration))
                } icon: {
                    Image(systemName: "stopwatch")
                }
            } else {
                Label {
                    let template = String(localized: "history.detail.set.reps",
                                          defaultValue: "%lld reps")
                    Text(String(format: template, set.reps))
                } icon: {
                    Image(systemName: "repeat")
                }
                if set.weightKg > 0 {
                    Label {
                        Text(UnitsFormatter.formatWeight(set.weightKg, preference: weightUnit))
                    } icon: {
                        Image(systemName: "scalemass")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var secondaryLine: some View {
        let parts = secondaryParts
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var secondaryParts: [String] {
        var out: [String] = []
        if let rpe = set.rpe {
            let template = String(localized: "history.detail.set.rpe", defaultValue: "RPE %.1f")
            out.append(String(format: template, rpe))
        }
        if set.restSeconds > 0 {
            let template = String(localized: "history.detail.set.rest", defaultValue: "rest %@")
            out.append(String(
                format: template,
                UnitsFormatter.formatDuration(seconds: set.restSeconds)
            ))
        }
        if let completed = set.completedAt {
            let f = DateFormatter()
            f.timeStyle = .short
            f.dateStyle = .none
            out.append(f.string(from: completed))
        }
        return out
    }
}

#Preview {
    NavigationStack {
        HistorySessionDetailView(session: WorkoutSession(goalRaw: Goal.hypertrophy.rawValue))
    }
}
