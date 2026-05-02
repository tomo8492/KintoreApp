// MARK: - SessionView
// CLAUDE.md §1.1 F-03 / §-1.4 / §-1.15 / §11 準拠。
// セッション実行画面のコンテナ。
// - 入力: GeneratorOutput + Goal(Builder から渡される)
// - 状態: SessionStore を @State で所有(Singleton 禁止規約)
// - 復元: SceneStorage の JSON 文字列を SessionRestoreSnapshot にデコードして再構築
// - 自動スクロール: ScrollViewReader + AutoScrollEffect
// - ライフサイクル: SessionLifecycleModifier(idle timer + SceneStorage 書き出し)

import SwiftUI
import SwiftData
import OSLog

struct SessionView: View {
    let initialOutput: GeneratorOutput?
    let goal: Goal
    let includesWarmup: Bool
    let includesCooldown: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependency) private var appDependency

    @State private var store: SessionStore?
    @State private var initError: String?

    /// currentItem が nil のときに autoScroll の id 引数に渡す固定 UUID。
    /// body 毎に UUID() を生成すると .task(id:) が毎回発火するため、定数で逃がす。
    private static let placeholderScrollId = UUID()

    /// SceneStorage はキー名が衝突するとシーン間で混じる。サフィックスで分離。
    @SceneStorage("workoutkit.session.snapshot") private var snapshotString: String = ""

    var body: some View {
        Group {
            if let store {
                content(store: store)
            } else if let initError {
                errorView(message: initError)
            } else {
                ProgressView().task { await prepareStore() }
            }
        }
        .navigationTitle("session.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(store: SessionStore) -> some View {
        if store.isFinished {
            FinishedView(onClose: { dismiss() })
        } else if store.isAborted {
            // 中断時は履歴に残す合意なので、ユーザーには簡素な確認だけ出して閉じる。
            FinishedView(onClose: { dismiss() }, isAborted: true)
        } else {
            runningContent(store: store)
        }
    }

    @ViewBuilder
    private func runningContent(store: SessionStore) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    progressHeader(store: store)
                    planList(store: store)
                    if store.isIntervalRunning, let remaining = store.intervalSecondsRemaining {
                        IntervalCountdownView(secondsRemaining: remaining)
                            .id("interval-countdown")
                    }
                    if let item = store.currentItem {
                        SessionSetInputPanel(
                            store: store,
                            item: item,
                            exercise: store.currentExercise,
                            onComplete: { store.completeCurrentSet() },
                            onSkip: { store.skipCurrentExercise() },
                            onAbort: { store.abort() }
                        )
                        .id("input-panel")
                    }
                }
                .padding(.vertical, 12)
            }
            .autoScrollToCurrent(
                proxy: proxy,
                currentId: store.currentItem?.id ?? Self.placeholderScrollId
            )
        }
        .sessionLifecycle(store: store, snapshotString: $snapshotString)
    }

    // MARK: - Header

    private func progressHeader(store: SessionStore) -> some View {
        let completed = store.completedSets.count
        let total = store.plan.reduce(0) { $0 + $1.plannedSetCount }
        return VStack(alignment: .leading, spacing: 4) {
            Text("session.header.goal \(store.goal.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: total > 0 ? Double(completed) / Double(total) : 0)
                .tint(.accentColor)
            let label = String(
                localized: "session.header.progress",
                defaultValue: "完了セット %lld / %lld"
            )
            Text(String(format: label, completed, total))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Plan list

    private func planList(store: SessionStore) -> some View {
        VStack(spacing: 6) {
            ForEach(Array(store.plan.enumerated()), id: \.element.id) { index, item in
                SessionExerciseRow(
                    item: item,
                    exercise: store.exercise(for: item.slug),
                    isCurrent: index == store.currentItemIndex,
                    isCompleted: index < store.currentItemIndex,
                    completedSetCount: store.completedSetCount(for: item)
                )
                .id(item.id)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Error / lifecycle

    private func errorView(message: String) -> some View {
        ContentUnavailableView(
            "session.error.title",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
    }

    @MainActor
    private func prepareStore() async {
        // C3: AppDependency 経由で LiveActivityClient を SessionStore に DI する。
        let liveActivity = appDependency.liveActivity

        // 1. SceneStorage に有効な復元情報があれば復元優先
        if let snapshot = SessionRestoreSnapshot.decoded(from: snapshotString) {
            do {
                store = try SessionStore(
                    modelContext: modelContext,
                    snapshot: snapshot,
                    liveActivity: liveActivity
                )
                Logger.session.info("SessionView restored from snapshot")
                return
            } catch {
                Logger.session.warning("snapshot restore failed: \(error.localizedDescription, privacy: .public)")
                snapshotString = ""
            }
        }

        // 2. Builder からの新規セッション
        guard let output = initialOutput else {
            initError = String(localized: "session.error.no-input",
                               defaultValue: "セッション情報がありません")
            return
        }

        do {
            store = try SessionStore(
                modelContext: modelContext,
                goal: goal,
                output: output,
                includesWarmup: includesWarmup,
                includesCooldown: includesCooldown,
                liveActivity: liveActivity
            )
        } catch let appError as AppError {
            initError = appError.errorDescription
        } catch {
            initError = error.localizedDescription
        }
    }
}

// MARK: - Finished view

private struct FinishedView: View {
    let onClose: () -> Void
    var isAborted: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isAborted ? "stop.circle.fill" : "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(isAborted ? Color.gray : Color.accentColor)
            Text(isAborted ? "session.finished.aborted" : "session.finished.title")
                .font(.title2.bold())
            Text(isAborted ? "session.finished.aborted.subtitle" : "session.finished.subtitle")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onClose) {
                Text("common.close")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        SessionView(
            initialOutput: GeneratorOutput(
                warmup: ["jumping-jacks"],
                main: ["barbell-back-squat", "bench-press"],
                cooldown: ["chest-stretch"]
            ),
            goal: .hypertrophy,
            includesWarmup: true,
            includesCooldown: true
        )
    }
    .modelContainer(for: Exercise.self, inMemory: true)
}
