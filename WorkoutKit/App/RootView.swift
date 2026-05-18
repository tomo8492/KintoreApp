// MARK: - RootView
// CLAUDE.md §-1.15 / §5 準拠。
// iPhone(compact)は TabView、iPad(regular)も TabView を使う(Library が
// NavigationSplitView を内包するため二重ネストを避ける)。
// 各 Feature の本体は順次差し込み、E1 で Templates タブが追加された。

import SwiftUI
import SwiftData
import OSLog

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appDependency) private var dependency
    @Environment(\.modelContext) private var modelContext

    /// Builder ウィザードが開いているかを SceneStorage で永続化する。
    /// `@State` だとアプリのバックグラウンド復帰で false に戻り、ウィザードが
    /// 途中で消える事象 (DEBUG_REPORT Major-11) があったため SceneStorage に切替。
    @SceneStorage("root.isBuilderPresented") private var isBuilderPresented = false

    /// v1.0 §6-5: 初回起動 3 日後の起動時にハードペイウォールを強制表示する。
    /// 表示判定は LaunchTrialTracker.shouldShowHardPaywallOnLaunch() で集約。
    @State private var forcedPaywall: PaywallContext?
    @State private var trialTracker = LaunchTrialTracker()

    /// M6 screenshot 撮影用: `-WORKOUTKIT_SEED_COMPLETED_SESSION 1` 起動引数で
    /// 完了済セッションを seed し、自動で完了画面 (SessionFinishedContent) を
    /// fullScreenCover で表示する。`#if DEBUG` で完全に消える。
    @State private var screenshotSummarySession: ScreenshotSummaryPayload?

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadRoot
            } else {
                iPhoneRoot
            }
        }
        .onAppear {
            // 初回起動日を記録(冪等)し、試用期間外 & 非 Pro なら Paywall 強制表示。
            trialTracker.recordFirstLaunchIfNeeded()
            if trialTracker.shouldShowHardPaywallOnLaunch(proGate: dependency.proGate) {
                // reason=nil で起動時の包括的な提示。閉じても再表示しない
                // (毎起動で出すと UX を破壊するため、現状は 1 ロード 1 回)。
                forcedPaywall = PaywallContext(feature: .unlimitedHistory)
            }
            applyScreenshotSeedIfNeeded()
        }
        .sheet(item: $forcedPaywall) { ctx in
            PaywallView(reason: ctx.feature)
        }
        .fullScreenCover(item: $screenshotSummarySession) { payload in
            SessionFinishedContent(
                session: payload.session,
                onClose: { screenshotSummarySession = nil }
            )
        }
    }

    // MARK: - Screenshot seed (DEBUG only)

    /// `-WORKOUTKIT_SEED_COMPLETED_SESSION 1` 起動引数を見て、完了済 WorkoutSession を
    /// modelContext に seed し、Session 完了画面を自動表示する。M6 撮影専用。
    /// Release ビルドでは `#if DEBUG` で完全に消えるため prod に影響しない。
    private func applyScreenshotSeedIfNeeded() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-WORKOUTKIT_SEED_COMPLETED_SESSION") else { return }
        do {
            let session = try ScreenshotSessionSeeder.seed(in: modelContext)
            screenshotSummarySession = ScreenshotSummaryPayload(session: session)
            Logger.app.info("DEBUG: SEED_COMPLETED_SESSION launch arg -> finished view presented")
        } catch {
            Logger.app.error("DEBUG seed failed: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    // MARK: - iPhone (compact)

    private var iPhoneRoot: some View {
        TabView {
            todayTab
                .tabItem { Label("tab.today", systemImage: "figure.strengthtraining.traditional") }

            templatesTab
                .tabItem { Label("tab.templates", systemImage: "square.stack.3d.up") }

            ExerciseListView()
                .tabItem { Label("tab.library", systemImage: "books.vertical") }

            historyTab
                .tabItem { Label("tab.history", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("tab.settings", systemImage: "gearshape") }
        }
    }

    // MARK: - iPad (regular)
    // iPad では Library 自身が NavigationSplitView を使うため、
    // Root は TabView でタブ切替のみ担当する(NavigationSplitView の入れ子を避ける)。

    private var iPadRoot: some View {
        TabView {
            todayTab
                .tabItem { Label("tab.today", systemImage: "figure.strengthtraining.traditional") }

            templatesTab
                .tabItem { Label("tab.templates", systemImage: "square.stack.3d.up") }

            ExerciseListView()
                .tabItem { Label("tab.library", systemImage: "books.vertical") }

            historyTab
                .tabItem { Label("tab.history", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("tab.settings", systemImage: "gearshape") }
        }
    }

    // MARK: - Templates tab (E1 で実装)

    private var templatesTab: some View {
        NavigationStack {
            TemplatesView()
        }
    }

    // MARK: - Today

    /// Today タブの入口。Builder ウィザードを fullScreenCover で開く CTA を出す。
    /// - iPhone/iPad とも fullScreenCover で BuilderView を独立して表示することで、
    ///   iPad 側で RootView の NavigationSplitView と BuilderView の NavigationSplitView
    ///   が二重にネストするのを避ける。
    private var todayTab: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("today.heading")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
            Text("today.subheading")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                isBuilderPresented = true
            } label: {
                Text("today.action.start-builder")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("today.action.start-builder"))
            .accessibilityHint(Text("a11y.today.start-builder.hint"))
            .accessibilityAddTraits(.isButton)
        }
        .padding()
        .fullScreenCover(isPresented: $isBuilderPresented) {
            BuilderView()
        }
    }

    // MARK: - History / Settings

    private var historyTab: some View {
        HistoryView()
    }
}

#Preview {
    RootView()
}

// MARK: - Screenshot seed support (DEBUG only)
//
// SessionFinishedContent を sheet で表示するために WorkoutSession を Identifiable
// 風にラップする(直接 WorkoutSession に Identifiable を生やすとモデル全体に波及
// するため、ローカル struct で囲む)。

private struct ScreenshotSummaryPayload: Identifiable {
    let session: WorkoutSession
    var id: UUID { session.id }
}

/// DEBUG 限定 seed。M6 session-summary-aicoach 撮影用に、modelContext に
/// 完了済 WorkoutSession + 3 セットを 1 回だけ挿入する。冪等のため、既に
/// `isManualEntry==false && goalRaw==hypertrophy` のセッションがあれば再利用する。
///
/// 注意: Release ビルドでは `#if DEBUG` で本ファイルごと消える(struct 単位で囲む
/// と Identifiable の不安定参照になるため、外部関数として括っている)。
#if DEBUG
enum ScreenshotSessionSeeder {
    static func seed(in context: ModelContext) throws -> WorkoutSession {
        // 既存 seed があれば再利用(2 回目の起動で履歴が増殖しないように)
        let existing = try context.fetch(FetchDescriptor<WorkoutSession>())
        if let already = existing.first(where: { $0.finishedAt != nil && $0.notes == "M6_SCREENSHOT_SEED" }) {
            return already
        }

        let exerciseFetch = FetchDescriptor<Exercise>()
        let allExercises = try context.fetch(exerciseFetch)
        // 撮影 UI 上「強そう」に見える 3 種目をピックアップ。実在 slug がヒット
        // しなければ fetch 順の先頭 3 件で代替(seed 内容に追従)。
        let wantedSlugs = ["barbell-back-squat", "barbell-bench-press", "barbell-deadlift"]
        let selected: [Exercise] = wantedSlugs.compactMap { slug in
            allExercises.first(where: { $0.slug == slug })
        }
        let exercisesForScreenshot: [Exercise] = selected.count == 3
            ? selected
            : Array(allExercises.prefix(3))

        let session = WorkoutSession(
            startedAt: Date().addingTimeInterval(-45 * 60),
            finishedAt: Date(),
            notes: "M6_SCREENSHOT_SEED",
            goalRaw: Goal.hypertrophy.rawValue,
            includesWarmup: true,
            includesCooldown: true
        )
        context.insert(session)

        for (idx, exercise) in exercisesForScreenshot.enumerated() {
            // セット 3 回 / 8 reps / 60kg を 3 種目 × 3 セット = 9 セット入れる。
            for setIdx in 0..<3 {
                let set = ExerciseSet(
                    order: idx * 3 + setIdx,
                    sectionRaw: SessionSection.main.rawValue,
                    reps: 8,
                    weightKg: 60 + Double(idx) * 10,
                    rpe: 7.5,
                    restSeconds: 90,
                    completedAt: Date().addingTimeInterval(TimeInterval(-30 * 60 + idx * 60)),
                    exercise: exercise,
                    session: session
                )
                context.insert(set)
            }
        }
        try context.save()
        return session
    }
}
#endif
