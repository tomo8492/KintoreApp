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
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

struct SessionView: View {
    let initialOutput: GeneratorOutput?
    let goal: Goal
    let includesWarmup: Bool
    let includesCooldown: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependency) private var appDependency
    /// F3: Reduce Motion 中はプログレスバーの値補間アニメを抑制する。
    /// SwiftUI の ProgressView はデフォルトで暗黙アニメを掛けるため明示的に nil 指定が必要。
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            // v1.0 §-1.17: iOS 26+ では FinishedView の下に AICoachView を差し込む。
            FinishedView(
                store: store,
                onClose: { dismiss() }
            )
        } else if store.isAborted {
            // 中断時は履歴に残す合意なので、ユーザーには簡素な確認だけ出して閉じる。
            // AI コーチは「完了したワークアウトに対するフィードバック」が前提なので
            // 中断時は表示しない。
            FinishedView(
                store: store,
                onClose: { dismiss() },
                isAborted: true,
                showAICoach: false
            )
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
        // 進捗ラベルは「完了セット N / 総セット M」。xcstrings 側で
        // session.header.progress が "セット %1$lld / %2$lld" に設定されている。
        let progressLabel = String(
            localized: "session.header.progress",
            defaultValue: "セット %lld / %lld"
        )
        // BUG A: 目的の表示名は goal.<rawValue>.title を解決してから %@ に流し込む。
        // 直接 rawValue を埋め込むと "session.header.goal hypertrophy" のような
        // 解決されない複合キーになり raw 表示されてしまう。
        // 2 段階で解決する:
        //   1. goal.<rawValue>.title をルックアップして「筋肥大」など localized
        //      な目的名を得る。
        //   2. session.header.goal %@(format: "目的: %@" / "Goal: %@")の %@
        //      に上で得た localized 目的名を埋め込む。
        let goalKey = "goal.\(store.goal.rawValue).title"
        let localizedGoal = String(localized: String.LocalizationValue(goalKey))
        // String(localized:) のうち `defaultValue:` 付き init は key が
        // StaticString に固定されるため runtime interpolation キーは渡せない。
        // String.LocalizationValue を取るオーバーロードを使う。
        let goalLabel = String(localized: "session.header.goal \(localizedGoal)")
        return VStack(alignment: .leading, spacing: 4) {
            Text(goalLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            ProgressView(value: total > 0 ? Double(completed) / Double(total) : 0)
                .tint(.accentColor)
                .animation(reduceMotion ? nil : .default, value: completed)
                .accessibilityLabel(Text("a11y.session.progress.bar"))
                .accessibilityValue(Text(String(format: progressLabel, completed, total)))
            Text(String(format: progressLabel, completed, total))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
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
// CLAUDE.md v1.0 §5-2: 完了画面の下部に AICoachView を差し込む。
// iOS 26+ では Foundation Models で 3 行の要約を生成、25 以下では非表示。

private struct FinishedView: View {
    let store: SessionStore
    let onClose: () -> Void
    var isAborted: Bool = false
    var showAICoach: Bool = true

    var body: some View {
        SessionFinishedContent(
            session: store.fetchSession(),
            onClose: onClose,
            isAborted: isAborted,
            showAICoach: showAICoach
        )
    }
}

// MARK: - Reusable finished content
// `FinishedView` の本体を切り出して `WorkoutSession?` を直接受け取る形にしておく。
// 本番経路では `FinishedView` 経由で SessionStore から取り出した session を渡す。
// DEBUG 限定の screenshot 経路では seeded session を直接渡せるため、
// 同じ UI を SessionStore 無しで再現できる(M6 session-summary-aicoach 撮影用)。
struct SessionFinishedContent: View {
    let session: WorkoutSession?
    let onClose: () -> Void
    var isAborted: Bool = false
    var showAICoach: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// v1.0 §6-6 相当:App Store レビュー依頼。SwiftUI ネイティブの
    /// `requestReview` action を使い、実際に呼ぶかどうかは ReviewPrompter
    /// (Singleton ではない static API)の判定に委ねる。
    @Environment(\.requestReview) private var requestReview

    /// F3/celebration: 完了時のみ、初回表示で 0.4→1.0 スケール + フェードインさせる。
    /// 中断時はこの state を一切変更しないため、従来どおり静的表示のまま。
    @State private var celebrateScale: CGFloat = 0.4
    @State private var celebrateOpacity: Double = 0
    @State private var celebrateBounce = false
    @State private var hasCelebrated = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroIcon
                Text(isAborted ? "session.finished.aborted" : "session.finished.title")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                Text(isAborted ? "session.finished.aborted.subtitle" : "session.finished.subtitle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // v1.0 §-1.17 AI ワークアウト要約
                // - 完了時のみ(abort 時は出さない、showAICoach=false で渡される)
                // - iOS 26 未満は AICoachView.isSupported=false なので空 View
                // - WorkoutInsightInput.from(session:previous:) で集計
                if showAICoach, AICoachView.isSupported,
                   let workoutSession = session {
                    AICoachView(
                        input: WorkoutInsightInput.from(
                            session: workoutSession,
                            previous: nil // v1.1+: 前回比較。今は省略してフォールバック動作。
                        )
                    )
                    .padding(.horizontal, 4)
                }

                Button(action: onClose) {
                    Text("common.close")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.primaryCTA)
                .accessibilityLabel(Text("common.close"))
                .accessibilityAddTraits(.isButton)
            }
            .padding()
        }
    }

    // MARK: - Hero icon / quiet celebration
    // 完了時のみ「静かな祝福」演出:ソフトなグロー + チェックマークの
    // スケールイン + symbolEffect(.bounce)。中断時はグロー無し・アニメ無しの
    // 従来どおりの表示を維持する(§5-3 の Live Activity 更新頻度規約とは無関係、
    // 単に isAborted 分岐で完全に見た目を分離しているだけ)。
    @ViewBuilder
    private var heroIcon: some View {
        if isAborted {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.gray)
                .accessibilityHidden(true)
        } else {
            ZStack {
                Circle()
                    .fill(AppColor.success.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .accessibilityHidden(true)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(AppColor.success)
                    .symbolEffect(.bounce, options: .nonRepeating, value: celebrateBounce)
            }
            .scaleEffect(celebrateScale)
            .opacity(celebrateOpacity)
            .accessibilityHidden(true)
            .onAppear { triggerCelebration() }
            // v1.0 §6-6 相当: 完了セッションを記録し、条件を満たせば「静かな祝福」の
            // 少し後(1.5秒)にレビュー依頼を出す。中断時はこの ZStack 自体が
            // 描画されないので isAborted 分岐を別途見る必要はない。
            .task { await handleReviewPromptIfNeeded() }
        }
    }

    /// 完了時に一度だけ呼ぶ。Reduce Motion 中はスケール/フェードアニメと
    /// symbolEffect のバウンスを両方スキップし、等倍・不透明で即表示する。
    /// ハプティクスは Reduce Motion に関係なく完了の合図として一度だけ鳴らす。
    private func triggerCelebration() {
        guard !hasCelebrated else { return }
        hasCelebrated = true

        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        if reduceMotion {
            celebrateScale = 1.0
            celebrateOpacity = 1.0
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                celebrateScale = 1.0
                celebrateOpacity = 1.0
            }
            celebrateBounce = true
        }
    }

    /// ワークアウト完了を ReviewPrompter に記録し、条件を満たしていれば
    /// お祝い演出が着地するのを待ってから(1.5秒)レビュー依頼を出す。
    /// 「割り込まない・懇願しない」という Apple のベストプラクティスに合わせ、
    /// 演出の直後ではなく少し間を置く。
    private func handleReviewPromptIfNeeded() async {
        ReviewPrompter.recordFinishedSession()
        guard ReviewPrompter.shouldPrompt() else { return }
        try? await Task.sleep(for: .seconds(1.5))
        guard !Task.isCancelled else { return }
        requestReview()
        ReviewPrompter.recordPrompted()
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
