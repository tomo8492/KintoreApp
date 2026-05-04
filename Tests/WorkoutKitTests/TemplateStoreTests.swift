// MARK: - TemplateStoreTests
// CLAUDE.md §1.1 F-05 / §-1.10 / §9.1 準拠。
// TemplateStore の CRUD と TemplateSeeder の冪等性を Swift Testing で凍結する。
// UserDefaults はテスト固有スイートで分離し、グローバル Defaults を汚さない。

import Foundation
import SwiftData
import Testing
@testable import WorkoutKit

@MainActor
@Suite("TemplateStore")
struct TemplateStoreTests {

    // MARK: - Helpers

    private static func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    /// 各テストごとに独立した UserDefaults を作って TemplateSeeder のフラグを分離。
    /// Defaults スイート名にテスト ID を含めるとリーク時に追跡しやすい。
    private static func makeDefaults() -> UserDefaults {
        let suite = "wktest.templatestore.\(UUID().uuidString)"
        // 同名キャッシュ汚染を避けるため、起動毎に必ずクリーンスタート。
        if let defaults = UserDefaults(suiteName: suite) {
            defaults.removePersistentDomain(forName: suite)
            return defaults
        }
        return .standard
    }

    // MARK: - Create / Update / Delete (Pro path)

    @Test("create() で isUserCreated=true なテンプレが追加される")
    func createInsertsUserTemplate() throws {
        let context = try Self.makeContext()
        let store = TemplateStore(context: context)
        store.reload()
        #expect(store.templates.isEmpty)

        let created = try store.create(
            name: "My Push",
            exerciseSlugs: ["push-up", "bench-press"],
            goal: .hypertrophy
        )

        #expect(created.isUserCreated == true)
        #expect(created.name == "My Push")
        #expect(created.exerciseSlugs == ["push-up", "bench-press"])
        #expect(created.defaultGoalRaw == "hypertrophy")
        #expect(store.templates.count == 1)
    }

    @Test("update() で部分更新できる(指定したフィールドだけが書き換わる)")
    func updatePartialFields() throws {
        let context = try Self.makeContext()
        let store = TemplateStore(context: context)
        let template = try store.create(
            name: "Original",
            exerciseSlugs: ["push-up"],
            goal: .hypertrophy
        )

        try store.update(template, name: "Renamed")
        #expect(template.name == "Renamed")
        #expect(template.exerciseSlugs == ["push-up"])
        #expect(template.defaultGoalRaw == "hypertrophy")

        try store.update(template, exerciseSlugs: ["push-up", "plank"], goal: .endurance)
        #expect(template.name == "Renamed")
        #expect(template.exerciseSlugs == ["push-up", "plank"])
        #expect(template.defaultGoalRaw == "endurance")
    }

    @Test("delete() でテンプレが消え、reload 後の templates にも残らない")
    func deleteRemovesTemplate() throws {
        let context = try Self.makeContext()
        let store = TemplateStore(context: context)
        let template = try store.create(name: "Tmp", exerciseSlugs: [], goal: .hypertrophy)
        #expect(store.templates.count == 1)

        try store.delete(template)
        #expect(store.templates.isEmpty)
    }

    // MARK: - Duplicate (Free path)

    @Test("duplicate() で複製は常に isUserCreated=true、slug 配列も複製される")
    func duplicateAlwaysProducesUserCreated() throws {
        let context = try Self.makeContext()
        let store = TemplateStore(context: context)

        // プリセット相当(isUserCreated=false)を直接挿入してから複製
        let preset = Template(
            name: "Push Day (PPL)",
            exerciseSlugsRaw: "[\"push-up\",\"bench-press\"]",
            defaultGoalRaw: Goal.hypertrophy.rawValue,
            isUserCreated: false
        )
        context.insert(preset)
        try context.save()
        store.reload()

        let copy = try store.duplicate(preset, newName: "Push Day (Copy)")

        #expect(copy.isUserCreated == true)
        #expect(copy.name == "Push Day (Copy)")
        #expect(copy.exerciseSlugs == ["push-up", "bench-press"])
        #expect(store.templates.count == 2)
    }

    // MARK: - Sort order (preset → user-created, createdAt 昇順)

    @Test("reload() で preset → user-created の順、各グループ内で createdAt 昇順")
    func reloadSortsPresetsBeforeUserCreated() throws {
        let context = try Self.makeContext()
        let now = Date.now
        // user-created 2件 + preset 2件 を時系列バラバラで投入
        context.insert(Template(name: "U2", exerciseSlugsRaw: "[]", defaultGoalRaw: "hypertrophy",
                                createdAt: now.addingTimeInterval(-50), isUserCreated: true))
        context.insert(Template(name: "P2", exerciseSlugsRaw: "[]", defaultGoalRaw: "hypertrophy",
                                createdAt: now.addingTimeInterval(-30), isUserCreated: false))
        context.insert(Template(name: "U1", exerciseSlugsRaw: "[]", defaultGoalRaw: "hypertrophy",
                                createdAt: now.addingTimeInterval(-100), isUserCreated: true))
        context.insert(Template(name: "P1", exerciseSlugsRaw: "[]", defaultGoalRaw: "hypertrophy",
                                createdAt: now.addingTimeInterval(-200), isUserCreated: false))
        try context.save()

        let store = TemplateStore(context: context)
        store.reload()

        #expect(store.templates.map(\.name) == ["P1", "P2", "U1", "U2"])
    }

    // MARK: - makeGeneratorOutput

    @Test("makeGeneratorOutput はテンプレの slug を main に詰めて warmup/cooldown は空")
    func makeGeneratorOutputBuildsMainOnly() throws {
        let context = try Self.makeContext()
        let store = TemplateStore(context: context)
        let template = try store.create(
            name: "T", exerciseSlugs: ["a", "b", "c"], goal: .hypertrophy
        )

        let output = store.makeGeneratorOutput(from: template)

        #expect(output.warmup == [])
        #expect(output.main == ["a", "b", "c"])
        #expect(output.cooldown == [])
    }

    // MARK: - TemplateSeeder 冪等性

    @Test("TemplateSeeder.seedIfNeeded は初回 3 件挿入、2回目は 0 件(冪等)")
    func seederIsIdempotentAcrossInvocations() throws {
        let context = try Self.makeContext()
        let defaults = Self.makeDefaults()

        let firstCount = try TemplateSeeder.seedIfNeeded(in: context, defaults: defaults)
        #expect(firstCount == TemplateSeeder.presets.count)

        let secondCount = try TemplateSeeder.seedIfNeeded(in: context, defaults: defaults)
        #expect(secondCount == 0)

        // フラグも立っている
        #expect(defaults.bool(forKey: TemplateSeeder.seededFlagKey) == true)
    }

    @Test("seed したプリセットは isUserCreated=false で保存される")
    func seededPresetsAreNotUserCreated() throws {
        let context = try Self.makeContext()
        let defaults = Self.makeDefaults()
        try TemplateSeeder.seedIfNeeded(in: context, defaults: defaults)

        let descriptor = FetchDescriptor<Template>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == TemplateSeeder.presets.count)
        for t in fetched {
            #expect(t.isUserCreated == false)
        }
    }

    @Test("プリセットを削除した後でも、seed フラグが立っているなら再 seed されない")
    func deletedPresetsAreNotRestored() throws {
        let context = try Self.makeContext()
        let defaults = Self.makeDefaults()
        try TemplateSeeder.seedIfNeeded(in: context, defaults: defaults)

        // 全 preset を削除
        let store = TemplateStore(context: context)
        store.reload()
        for t in store.templates {
            try store.delete(t)
        }
        #expect(store.templates.isEmpty)

        // 再 seed しても 0 件(フラグ立っているから)
        let count = try TemplateSeeder.seedIfNeeded(in: context, defaults: defaults)
        #expect(count == 0)
        store.reload()
        #expect(store.templates.isEmpty)
    }
}
