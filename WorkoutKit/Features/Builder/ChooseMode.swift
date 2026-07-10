// MARK: - ChooseMode
// CLAUDE.md §1.1 F-01a / workout-cool Issue #93 準拠。
// 候補プール(条件適合の全種目)を表示し、ロックする種目を選ばせる。
// 残りの枠は WorkoutGenerator が Shuffle で埋める。
//
// 設計メモ:
// - 候補プールは WorkoutGenerator.candidatePool で取得(generateMain と同じ前段フィルタ)。
// - ロックは BuilderStore.toggleLock(_:) 経由で input.lockedExerciseSlugs に書き戻す。
// - 「ロックして再生成」ボタンで store.regenerate(in:) を呼ぶ。
// - 候補が空の場合は ContentUnavailableView を表示する。
// - View 内でローカライズ済み表示名は Exercise.localizedName(B3 で追加)を使用。

import SwiftUI
import SwiftData
import OSLog

struct ChooseMode: View {
    @Bindable var store: BuilderStore
    @Environment(\.modelContext) private var modelContext

    /// 候補プールのキャッシュ。computed property のままだと body 毎に
    /// SwiftData fetch + フィルタ + ソートが走り、ロックトグルや再生成のたびに
    /// メインスレッドを長時間占有してしまう(=画面フリーズの一因)。
    /// 入力条件(goal/muscles/equipment)が変わった時だけ再fetchする。
    @State private var pool: [Exercise] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if pool.isEmpty {
                ContentUnavailableView(
                    "builder.step.result.choose.empty.title",
                    systemImage: "rectangle.dashed",
                    description: Text("builder.step.result.choose.empty.description")
                )
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                candidateList
            }

            regenerateButton
        }
        .task(id: poolKey) {
            await reloadPool()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("builder.step.result.choose.heading")
                .font(.headline)
            Text("builder.step.result.choose.subheading \(store.lockedSlugs.count) \(pool.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var candidateList: some View {
        VStack(spacing: 0) {
            ForEach(Array(pool.enumerated()), id: \.element.slug) { index, exercise in
                CandidateRow(
                    exercise: exercise,
                    isLocked: store.lockedSlugs.contains(exercise.slug)
                ) {
                    store.toggleLock(exercise.slug)
                }
                if index < pool.count - 1 {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .fill(Color.gray.opacity(0.08))
        )
    }

    private var regenerateButton: some View {
        Button(action: regenerate) {
            HStack {
                if store.isGenerating {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "lock.shield")
                        .accessibilityHidden(true)
                }
                Text("builder.step.result.choose.action.regenerate")
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
        }
        .buttonStyle(.plain)
        .disabled(store.isGenerating)
        .accessibilityLabel(Text("builder.step.result.choose.action.regenerate"))
        .accessibilityHint(Text("a11y.builder.choose.regenerate.hint"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Data

    /// `pool` の再取得トリガー。入力条件(goal/muscles/equipment)が変わったら
    /// .task(id:) が再発火して reloadPool() が走る。lockedExerciseSlugs は
    /// 候補プールの母集合には影響しないので、ここには含めない(無駄fetch回避)。
    private var poolKey: String {
        let muscles = store.input.muscles
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
        let equip = store.input.equipment
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
        return "\(store.input.goal.rawValue)|\(muscles)|\(equip)"
    }

    /// 候補プールを SwiftData から取得し直してキャッシュに格納する。
    /// MainActor 上で動くが .task で呼ばれるので body の評価とは別フレームで走る。
    @MainActor
    private func reloadPool() async {
        do {
            pool = try WorkoutGenerator.candidatePool(store.input, in: modelContext)
        } catch {
            let message = error.localizedDescription
            Logger.generator.warning("ChooseMode candidatePool failed: \(message, privacy: .public)")
            pool = []
        }
    }

    private func regenerate() {
        store.regenerate(in: modelContext)
    }
}

// MARK: - Row

private struct CandidateRow: View {
    let exercise: Exercise
    let isLocked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isLocked ? "lock.fill" : "lock.open")
                    .font(.body)
                    .foregroundStyle(isLocked ? Color.accentColor : Color.secondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.localizedName)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(exercise.slug)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityHidden(true)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(exercise.localizedName))
        .accessibilityValue(Text(isLocked ? "a11y.builder.result.locked" : "a11y.builder.result.unlocked"))
        .accessibilityHint(Text("a11y.builder.choose.toggle.hint"))
        .accessibilityAddTraits(isLocked ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    ChooseMode(store: BuilderStore())
        .modelContainer(for: Exercise.self, inMemory: true)
        .padding()
}
