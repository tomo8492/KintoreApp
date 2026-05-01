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
    @State private var dependency = AppDependency(proGate: ProFeatureGate())

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
                .task {
                    await runStartupSeed()
                }
        }
        .modelContainer(modelContainer)
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
