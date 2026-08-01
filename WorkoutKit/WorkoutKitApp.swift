// MARK: - WorkoutKitApp
// アプリのエントリポイント。CLAUDE.md v1.0 §3 / §4-3 / §6-3 準拠。
// - ModelContainer は SchemaV1 + WorkoutKitMigrationPlan で構築
// - 配置は appSupport/WorkoutKit.store
// - 起動時に ExerciseSeeder / TemplateSeeder を順に走らせる
// - v1.0: PurchaseManager.shared を configure し、ProFeatureGate にブリッジする

import SwiftUI
import SwiftData
import OSLog

@main
struct WorkoutKitApp: App {
    /// ModelContainer はアプリ起動時に1回だけ作る。
    /// `.modelContainer(_:)` で全 View に共有する(Singleton 禁止規約に抵触しない、§4.1)。
    private let modelContainer: ModelContainer
    /// AppDependency は v1.0 で purchaseManager / restTimer フィールドが追加された。
    /// PurchaseManager.shared / RestTimerManager.shared は nonisolated(unsafe) static let
    /// なので、ここで参照しても問題ない。
    /// v1.0: 旧 StoreKitClient(buy-once IAP `com.tomo.workoutkit.pro.unlock` 前提)は
    /// retire 済み。Restore Purchase は PurchaseManager(RevenueCat 経由)が担当する。
    @State private var dependency: AppDependency = {
        let gate = ProFeatureGate()
        return AppDependency(
            proGate: gate,
            liveActivity: LiveActivityClient(),
            restTimer: RestTimerManager.shared,
            purchaseManager: PurchaseManager.shared,
            purchaseRestorer: PurchaseManager.shared,
            annotationLoader: ExerciseAnnotationLoader(),
            watchSync: PhoneWatchSyncManager()
        )
    }()

    /// E3: Settings の Theme 切替を Scene ルートに反映する。
    /// 文字列で持つのは @AppStorage の素直な使い方に合わせるため。
    @AppStorage(SettingsKey.theme) private var themeRaw: String = ThemePreference.system.rawValue

    /// scenePhase が `.active` に戻ったタイミングで StoreKit のエンタイトルメントを
    /// 再評価する(家族共有解除・別端末払戻し・バックグラウンド長期化からの復帰で
    /// Transaction.updates が間に合わないケースの保険)。
    @Environment(\.scenePhase) private var scenePhase

    /// E2: ストア破損等で `ModelContainer` の初期化に失敗した場合、この 1 回に限り
    /// 「データを再作成しました」バナーを RootView 側で表示するためのフラグキー。
    static let storeDidRecoverDefaultsKey = "workoutkit.store.didRecover"

    init() {
        self.modelContainer = Self.makeModelContainer()
    }

    /// E2: ModelContainer 構築を「通常配置 → 既存ストアを退避して作り直し →
    /// 最終手段としてインメモリ」の 3 段構えにする。
    /// 従来は初回の `ModelContainer(for:)` 失敗を即 `fatalError` していたため、
    /// ストアファイル破損(ディスク書き込み中クラッシュ、OS アップデート起因等)が
    /// 起きたユーザーは二度と起動できなくなっていた。
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)

        // Step 1: 通常配置(デフォルトの appSupport/default.store)で試す。
        do {
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            return try ModelContainer(
                for: schema,
                migrationPlan: WorkoutKitMigrationPlan.self,
                configurations: configuration
            )
        } catch {
            Logger.app.fault("ModelContainer init failed: \(error.localizedDescription, privacy: .public)")
        }

        // Step 2: 既存ストアファイルが壊れている可能性が高いので、明示的な URL で
        // 退避(リネーム)してから同じ URL に作り直す。migrationPlan を経由すると
        // 壊れたストアをまた読みにいってしまうため、ここでは migrationPlan なしで
        // 新規ストアとして作る。
        let storeURL = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false).url
        moveAsideCorruptStore(at: storeURL)
        do {
            let recoveryConfiguration = ModelConfiguration(
                schema: schema,
                url: storeURL
            )
            let container = try ModelContainer(for: schema, configurations: recoveryConfiguration)
            UserDefaults.standard.set(true, forKey: storeDidRecoverDefaultsKey)
            Logger.app.error("ModelContainer recovered by recreating store at \(storeURL.path, privacy: .public)")
            return container
        } catch {
            Logger.app.fault("ModelContainer recovery (recreate store) failed: \(error.localizedDescription, privacy: .public)")
        }

        // Step 3: 最終手段。インメモリで起動し、少なくともアプリはクラッシュせず使える
        // 状態にする(このセッション内のデータは保存されない)。
        do {
            let inMemoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: inMemoryConfiguration)
            UserDefaults.standard.set(true, forKey: storeDidRecoverDefaultsKey)
            Logger.app.fault("ModelContainer falling back to in-memory store; changes will not persist")
            return container
        } catch {
            // インメモリ構成の ModelContainer 初期化はディスク I/O やマイグレーションに
            // 依存しないため、Schema 自体が壊れていない限り実質的に失敗しない。
            // ここまで到達するのはスキーマ定義そのものが不正なプログラマエラーの場合のみで、
            // 復旧不能なため fatalError は妥当(§4.1 ModelContext は @MainActor 前提のため
            // これ以上フォールバックする手段が無い)。
            Logger.app.fault("ModelContainer in-memory fallback failed: \(error.localizedDescription, privacy: .public)")
            fatalError("Failed to initialize ModelContainer even in-memory: \(error)")
        }
    }

    /// 壊れている疑いのあるストアファイル一式(store 本体 + -wal / -shm)を
    /// タイムスタンプ付きでリネーム退避する。退避に失敗しても(ファイルが
    /// そもそも存在しない等)復旧処理自体は継続する。
    private static func moveAsideCorruptStore(at storeURL: URL) {
        let fileManager = FileManager.default
        let suffix = "corrupt-\(Int(Date.now.timeIntervalSince1970))"
        let relatedExtensions = ["", "-wal", "-shm"]
        for ext in relatedExtensions {
            let source = URL(fileURLWithPath: storeURL.path + ext)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let destination = URL(fileURLWithPath: storeURL.path + ext + "." + suffix)
            do {
                try fileManager.moveItem(at: source, to: destination)
            } catch {
                Logger.app.error("Failed to move aside corrupt store file \(source.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appDependency, dependency)
                .preferredColorScheme(currentTheme.colorScheme)
                .task {
                    await runStartupSeed()
                }
                .task {
                    // CLAUDE.md v1.0 §6-4: PurchaseManager をまず configure。
                    // proGateBridge を AppDependency.defaultValue ではなくここで配線する
                    // (defaultValue は nonisolated 評価で @MainActor プロパティに書けないため)。
                    let purchase = dependency.purchaseManager
                    let gate = dependency.proGate
                    purchase.proGateBridge = { [weak gate] active in
                        gate?.setIsPro(active)
                    }
                    purchase.configureIfPossible()

                    applyDebugProOverrideIfNeeded()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            // v1.0: PurchaseManager に entitlement を再評価させる
                            // (払戻/家族共有/別端末からの状態変化を取り込むため)。
                            await dependency.purchaseManager.refresh()
                        }
                    }
                }
                .task {
                    // v1.1 Watch quick-log(Phase 2-2): WCSession を activate し、
                    // Watch → iPhone の受信ハンドラを配線する。
                    // `self`(WorkoutKitApp は struct)を escaping closure に持ち込みたくないため、
                    // 取り込みロジックは状態を持たない WatchQuickLogIngestor.ingest(_:into:) に
                    // 切り出し、ここでは ModelContainer だけをキャプチャする。
                    let sync = dependency.watchSync
                    let container = modelContainer
                    sync.onReceiveLoggedSets = { sets in
                        WatchQuickLogIngestor.ingest(sets, into: container, watchSync: sync)
                    }
                    sync.activate()
                }
        }
        .modelContainer(modelContainer)
    }

    private var currentTheme: ThemePreference {
        ThemePreference(rawValue: themeRaw) ?? .system
    }

    // MARK: - Debug-only Pro override (UI test hook)

    /// `-WORKOUTKIT_FAKE_PRO 1` 起動引数で proGate.isPro を強制 true にする。
    /// post-purchase の UI 状態(YouTube ボタン解放、CSV import/export 有効化、
    /// 31 日以前の履歴閲覧、advanced charts など)を XCUITest から検証するための
    /// テストフック。Release ビルドでは `#if DEBUG` で完全に消える。
    @MainActor
    private func applyDebugProOverrideIfNeeded() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-WORKOUTKIT_FAKE_PRO") {
            dependency.proGate._setProForPreview(true)
            Logger.app.info("DEBUG: WORKOUTKIT_FAKE_PRO launch arg -> proGate.isPro=true")
        }
        #endif
    }

    // MARK: - Startup

    /// 初回起動 / アップグレード時の seed 投入を非同期で実行する。
    /// 失敗してもアプリ自体は起動させる(seed なしでも UI は動く)。
    /// テンプレ seed は Exercise seed の後に行う(プリセットが Exercise.slug を参照するため)。
    @MainActor
    private func runStartupSeed() async {
        let context = modelContainer.mainContext
        do {
            let inserted = try ExerciseSeeder.seedIfNeeded(in: context)
            Logger.app.info("startup seed completed: \(inserted) exercises inserted")
        } catch {
            Logger.app.error("startup seed failed: \(error.localizedDescription, privacy: .public)")
        }
        do {
            let insertedTemplates = try TemplateSeeder.seedIfNeeded(in: context)
            Logger.app.info("template seed completed: \(insertedTemplates) presets inserted")
        } catch {
            Logger.app.error("template seed failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - WatchQuickLogIngestor (v1.1 Watch quick-log, Phase 2-2)
//
// Watch → iPhone: `PhoneWatchSyncManager.onReceiveLoggedSets` から届いた
// `WatchLoggedSet` 群を SwiftData の WorkoutSession / ExerciseSet に取り込む。
// ManualEntryStore.save(modelContext:exerciseLookup:) の保存パターン(§ManualEntryStore)を
// 踏襲し、新しいスキーマフィールドは追加しない。
//
// 冪等化:
//   `WatchLoggedSet.id` を UserDefaults に「直近取り込み済み ID」として最大 200 件保持し、
//   再送・重複配信(`transferUserInfo` の到達保証キュー特性)を弾く。
//
// セッションの特定:
//   WorkoutSession にはスキーマ上「Watch 由来」を示すフラグが無いため、
//   「今日作成した Watch クイック記録セッションの id」を UserDefaults に持たせて
//   同日中の複数回受信を同一セッションに追記する(日付が変われば新規作成)。
//
// Audit A2:
//   - `finishedAt` を毎回スタンプする。History / Today は `finishedAt != nil` で
//     フィルタするため(HistoryView.swift / TodayDashboardView.swift)、これが無いと
//     Watch 由来のセットが一覧にもダッシュボードにも一切出てこない。
//   - phantom session ロールバック: 新規作成した WorkoutSession に 1 件もセットが
//     入らなかった場合(全件が unknown slug 等)、空セッションを context から
//     `delete` して autosave による永続化を防ぐ(既存セッションへの追記失敗時は
//     何も壊れていないので削除しない)。
//   - 保存成功後、今日のサマリを Watch Widget 用に再配信する
//     (WatchSummaryBridge.write は iPhone 側ストアの整合性維持、
//     watchSync.sendTodaySummary は Watch 側 Smart Stack Widget への配信)。
@MainActor
private enum WatchQuickLogIngestor {

    private static let maxIngestedIDs = 200
    private static let ingestedIDsKey = "watch.quickLog.ingestedSetIDs.v1"
    private static let todaySessionIDKey = "watch.quickLog.todaySessionID.v1"
    private static let todaySessionDateKey = "watch.quickLog.todaySessionDate.v1"

    /// - Parameter watchSync: 取り込み後に「今日のサマリ」を Watch へ配信するための DI。
    ///   `WatchQuickLogIngestor` は static のため、呼び出し元(WorkoutKitApp の
    ///   `.task` クロージャ)が `dependency.watchSync` をそのまま渡す。
    static func ingest(_ sets: [WatchLoggedSet], into container: ModelContainer, watchSync: PhoneWatchSyncManager) {
        guard !sets.isEmpty else { return }
        let context = container.mainContext

        var ingestedIDs = loadIngestedIDs()
        let ingestedSet = Set(ingestedIDs)
        let newSets = sets.filter { !ingestedSet.contains($0.id) }
        guard !newSets.isEmpty else {
            Logger.app.info("watch quick-log ingest: no new sets (received=\(sets.count))")
            return
        }

        let (session, isNewSession) = findOrCreateTodaySession(in: context)

        var order = session.sets.count
        var insertedCount = 0
        for set in newSets.sorted(by: { $0.loggedAt < $1.loggedAt }) {
            let slug = set.slug
            let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.slug == slug })
            guard let exercise = (try? context.fetch(descriptor))?.first else {
                Logger.app.warning("watch quick-log ingest: unknown exercise slug=\(slug, privacy: .public)")
                continue
            }
            let entity = ExerciseSet(
                order: order,
                sectionRaw: SessionSection.main.rawValue,
                reps: set.reps,
                weightKg: set.weightKg,
                restSeconds: 60,
                completedAt: set.loggedAt,
                exercise: exercise,
                session: session
            )
            context.insert(entity)
            order += 1
            insertedCount += 1
            ingestedIDs.append(set.id)
        }

        guard insertedCount > 0 else {
            if isNewSession {
                // このセッションはこの呼び出しで新規作成したが 1 件も有効なセットが
                // 無かった(全件 unknown slug 等)。空のまま context に残すと autosave で
                // phantom session が永続化されてしまうため削除し、UserDefaults の
                // 「今日のセッション」参照もリセットして矛盾を防ぐ(次回呼び出しで作り直す)。
                context.delete(session)
                UserDefaults.standard.removeObject(forKey: todaySessionIDKey)
                UserDefaults.standard.removeObject(forKey: todaySessionDateKey)
                Logger.app.info("watch quick-log ingest: no valid sets, rolled back phantom session")
            }
            return
        }

        // Audit A2: History / Today の `finishedAt != nil` フィルタに乗せるため、
        // 取り込んだセットのうち最新の loggedAt を finishedAt としてスタンプする。
        // 新規作成 / 既存セッションへの追記、どちらのパスでも同じ扱いにする。
        session.finishedAt = newSets.map(\.loggedAt).max() ?? .now

        do {
            try context.save()
            saveIngestedIDs(ingestedIDs)
            Logger.app.info("watch quick-log ingest: inserted \(insertedCount) sets into session=\(session.id, privacy: .public)")
            pushTodaySummary(session: session, watchSync: watchSync)
        } catch {
            Logger.app.error("watch quick-log ingest save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 「今日の Watch クイック記録セッション」を探すか、無ければ ManualEntry と同じ
    /// 意味論(goalRaw=hypertrophy / isManualEntry=true)で新規作成する。
    /// `isNew` は phantom session ロールバック(Audit A2)判定に使う。
    private static func findOrCreateTodaySession(in context: ModelContext) -> (session: WorkoutSession, isNew: Bool) {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date.now
        if let idString = UserDefaults.standard.string(forKey: todaySessionIDKey),
           let id = UUID(uuidString: idString),
           let storedDate = UserDefaults.standard.object(forKey: todaySessionDateKey) as? Date,
           calendar.isDate(storedDate, inSameDayAs: now) {
            let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })
            if let existing = (try? context.fetch(descriptor))?.first {
                return (existing, false)
            }
        }

        let session = WorkoutSession(
            goalRaw: Goal.hypertrophy.rawValue,
            includesWarmup: false,
            includesCooldown: false,
            isManualEntry: true
        )
        context.insert(session)
        UserDefaults.standard.set(session.id.uuidString, forKey: todaySessionIDKey)
        UserDefaults.standard.set(now, forKey: todaySessionDateKey)
        return (session, true)
    }

    /// 保存成功後、今日のサマリを iPhone 側ストアと Watch の双方へ反映する。
    /// Watch クイック記録には明示的な「完了」概念が無いため、1 セットでも保存できていれば
    /// `isCompletedToday: true` として扱う(SessionStore.finish() と同じ意味論)。
    private static func pushTodaySummary(session: WorkoutSession, watchSync: PhoneWatchSyncManager) {
        let summary = TodaySessionSummary.build(from: session.sets, isCompletedToday: true)
        WatchSummaryBridge.write(summary)
        watchSync.sendTodaySummary(summary)
    }

    private static func loadIngestedIDs() -> [UUID] {
        (UserDefaults.standard.stringArray(forKey: ingestedIDsKey) ?? []).compactMap(UUID.init(uuidString:))
    }

    private static func saveIngestedIDs(_ ids: [UUID]) {
        let capped = ids.suffix(maxIngestedIDs)
        UserDefaults.standard.set(capped.map(\.uuidString), forKey: ingestedIDsKey)
    }
}
