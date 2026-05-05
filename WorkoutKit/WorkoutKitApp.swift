// MARK: - WorkoutKitApp
// アプリのエントリポイント。CLAUDE.md §-1.3 / §-1.5 / §4.1 準拠。
// - ModelContainer は SchemaV1 + WorkoutKitMigrationPlan で構築
// - 配置は appSupport/WorkoutKit.store(§-1.5)
// - 起動時に ExerciseSeeder.seedIfNeeded を一度だけ走らせる

import SwiftUI
import SwiftData
import OSLog

@main
struct WorkoutKitApp: App {
    /// ModelContainer はアプリ起動時に1回だけ作る。
    /// `.modelContainer(_:)` で全 View に共有する(Singleton 禁止規約に抵触しない、§4.1)。
    private let modelContainer: ModelContainer
    /// C3: LiveActivityClient を AppDependency に DI する。
    /// F1: StoreKitClient を同梱、起動時 `start()` で entitlement の購読を開始する。
    /// E3: 同じ StoreKitClient を purchaseRestorer としても渡す
    /// (StoreKitClient: PurchaseRestoring 拡張)。
    @State private var dependency: AppDependency = {
        let gate = ProFeatureGate()
        let storeKit = StoreKitClient(proGate: gate)
        return AppDependency(
            proGate: gate,
            liveActivity: LiveActivityClient(),
            storeKitClient: storeKit,
            purchaseRestorer: storeKit
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
            rootContent
                .environment(\.appDependency, dependency)
                .preferredColorScheme(currentTheme.colorScheme)
                .task {
                    await runStartupSeed()
                }
                .task {
                    // CLAUDE.md §-1.14。Transaction.currentEntitlements の購読を起動時に開始。
                    await dependency.storeKitClient.start()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await dependency.storeKitClient.refreshEntitlementsOnForeground() }
                    }
                }
        }
        .modelContainer(modelContainer)
    }

    /// sample/2d-lottie-prototype: 環境変数 `WK_LOTTIE_GALLERY=1` のときのみ
    /// 5 種目の ExerciseAnimationView を縦に並べた DEBUG ギャラリーを表示する。
    /// `xcrun simctl launch` で渡すには `SIMCTL_CHILD_WK_LOTTIE_GALLERY=1` を
    /// 親プロセスにセットする(CommandLine.arguments は simctl が自身の引数として
    /// パースし得るため、env var を使う方が安定する)。
    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.environment["WK_LOTTIE_GALLERY"] == "1" {
            LottieGalleryDebugView()
        } else {
            RootView()
        }
        #else
        RootView()
        #endif
    }

    private var currentTheme: ThemePreference {
        ThemePreference(rawValue: themeRaw) ?? .system
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
