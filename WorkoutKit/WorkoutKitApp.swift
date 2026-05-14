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
    @State private var dependency: AppDependency = {
        let gate = ProFeatureGate()
        let storeKit = StoreKitClient(proGate: gate)
        return AppDependency(
            proGate: gate,
            liveActivity: LiveActivityClient(),
            restTimer: RestTimerManager.shared,
            purchaseManager: PurchaseManager.shared,
            storeKitClient: storeKit,
            purchaseRestorer: storeKit,
            annotationLoader: ExerciseAnnotationLoader()
        )
    }()

    /// E3: Settings の Theme 切替を Scene ルートに反映する。
    /// 文字列で持つのは @AppStorage の素直な使い方に合わせるため。
    @AppStorage(SettingsKey.theme) private var themeRaw: String = ThemePreference.system.rawValue

    /// scenePhase が `.active` に戻ったタイミングで StoreKit のエンタイトルメントを
    /// 再評価する(家族共有解除・別端末払戻し・バックグラウンド長期化からの復帰で
    /// Transaction.updates が間に合わないケースの保険)。
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            // ModelContainer.init(for:) は Schema インスタンスを取る。
            // VersionedSchema 型をそのまま渡すオーバーロードは無いので
            // 一旦 Schema(versionedSchema:) でくるんでから渡す。
            let schema = Schema(versionedSchema: SchemaV1.self)
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            self.modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: WorkoutKitMigrationPlan.self,
                configurations: configuration
            )
        } catch {
            // ここで失敗するとアプリが起動できない。実機で頻発したら
            // クリーンインストール導線(設定→リセット)を後で追加する。
            Logger.app.fault("ModelContainer init failed: \(error.localizedDescription, privacy: .public)")
            fatalError("Failed to initialize ModelContainer: \(error)")
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

                    // 後方互換: 既存 StoreKitClient(actor) も並行で動かす。
                    // v0.5 で完全に PurchaseManager に置換予定だが、現在は両系統を共存。
                    await dependency.storeKitClient.start()
                    applyDebugProOverrideIfNeeded()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            // v1.0: PurchaseManager 側も entitlement を再評価する
                            // (払戻/家族共有/別端末からの状態変化を取り込むため)。
                            await dependency.purchaseManager.refresh()
                            await dependency.storeKitClient.refreshEntitlementsOnForeground()
                        }
                    }
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
