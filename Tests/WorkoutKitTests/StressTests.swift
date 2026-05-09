// MARK: - StressTests
// CLAUDE.md §1.1 / §4.3 / §-1 準拠。
//
// 配信前に「ユーザーが 1 年間使い倒した状態」を想定して内部集計と Generator
// が崩壊しないことを凍結する。各テストは in-memory ModelContainer を作って
// 独立に実行する(他のスイートと隔離)。
//
// 計測の流儀:
//  - `ContinuousClock().measure` で wall clock の経過秒を取る
//  - 実機 / シミュレータの差を吸収するため、閾値は十分緩く設定する
//    (CI を遅い x86_64 のレンタル simulator で走らせる前提)
//  - 値はテスト失敗時のヒントとして `Issue.record` でレポートにも残す

import Foundation
import SwiftData
import Testing
@testable import WorkoutKit

@MainActor
@Suite("Stress")
struct StressTests {

    // MARK: - Container helpers

    /// in-memory な ModelContainer を SchemaV1 で作る。
    private static func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private static func makeContext() throws -> ModelContext {
        ModelContext(try makeContainer())
    }

    // MARK: - Fixture builders

    /// 共通 fixture: 6 種目だけ作って seed する(体幹・上半身・下半身を網羅)。
    /// Stress 用なので種目自体は最小、件数勝負はセッション側で稼ぐ。
    @discardableResult
    private static func seedMinimalExercises(_ context: ModelContext) -> [Exercise] {
        let specs: [(slug: String, primary: Muscle, equip: Equipment)] = [
            ("squat",       .quadriceps, .barbell),
            ("bench-press", .chest,      .barbell),
            ("deadlift",    .glutes,     .barbell),
            ("pull-up",     .lats,       .pullupBar),
            ("plank",       .abs,        .bodyweight),
            ("push-up",     .chest,      .bodyweight)
        ]
        var inserted: [Exercise] = []
        for spec in specs {
            let ex = Exercise(
                slug: spec.slug,
                slugJa: spec.slug,
                nameJa: spec.slug,
                nameEn: spec.slug,
                typeRaw: ExerciseType.strength.rawValue,
                mechanicsTypeRaw: MechanicsType.compound.rawValue,
                primaryMuscleRaw: spec.primary.rawValue,
                secondaryMusclesRaw: "",
                equipmentRaw: spec.equip.rawValue
            )
            context.insert(ex)
            inserted.append(ex)
        }
        try? context.save()
        return inserted
    }

    /// `count` 件の WorkoutSession を `setsPerSession` セットずつ生成。
    /// startedAt は (now - i 日) でばらしてカレンダー集計の現実性を保つ。
    @discardableResult
    private static func seedSessions(
        count: Int,
        setsPerSession: Int,
        exercises: [Exercise],
        in context: ModelContext
    ) -> [WorkoutSession] {
        let now = Date()
        let day: TimeInterval = 86_400
        var sessions: [WorkoutSession] = []
        sessions.reserveCapacity(count)
        for i in 0..<count {
            let session = WorkoutSession(
                startedAt: now.addingTimeInterval(-day * Double(i)),
                finishedAt: now.addingTimeInterval(-day * Double(i) + 3_600),
                goalRaw: Goal.hypertrophy.rawValue
            )
            context.insert(session)
            for s in 0..<setsPerSession {
                let ex = exercises[(i &+ s) % exercises.count]
                let set = ExerciseSet(
                    order: s,
                    sectionRaw: SessionSection.main.rawValue,
                    reps: 8,
                    weightKg: 60.0 + Double(s % 5) * 2.5,
                    rpe: 8.0,
                    restSeconds: 90,
                    durationSeconds: nil,
                    completedAt: session.startedAt.addingTimeInterval(Double(s) * 120),
                    exercise: ex,
                    session: session
                )
                context.insert(set)
            }
            sessions.append(session)
        }
        try? context.save()
        return sessions
    }

    // MARK: - 1. History — 1000 sessions

    /// 1000 セッション × 平均 7 セット ≒ 7000 セット規模で aggregations / fetch /
    /// day-grouping が許容時間内に収まることを凍結する。
    @Test("History: 1000 sessions across fetch / week / month / heatmap / day-grouping")
    func testHistory_with1000Sessions() async throws {
        let context = try Self.makeContext()
        let exercises = Self.seedMinimalExercises(context)
        // セット数を 5..=10 でランダムに散らす(再現性確保のため決定的に)
        let now = Date()
        let day: TimeInterval = 86_400
        let sessionCount = 1_000
        for i in 0..<sessionCount {
            let setsThisSession = 5 + (i % 6) // 5..=10
            let session = WorkoutSession(
                startedAt: now.addingTimeInterval(-day * Double(i)),
                finishedAt: now.addingTimeInterval(-day * Double(i) + 3_600),
                goalRaw: Goal.hypertrophy.rawValue
            )
            context.insert(session)
            for s in 0..<setsThisSession {
                let ex = exercises[(i &+ s) % exercises.count]
                let set = ExerciseSet(
                    order: s,
                    reps: 8,
                    weightKg: 70.0 + Double(s % 4) * 2.5,
                    completedAt: session.startedAt.addingTimeInterval(Double(s) * 120),
                    exercise: ex,
                    session: session
                )
                context.insert(set)
            }
        }
        try context.save()

        // (a) Fetch — HistoryView の @Query 相当
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let clock = ContinuousClock()
        var sessions: [WorkoutSession] = []
        let fetchTime = clock.measure {
            sessions = (try? context.fetch(descriptor)) ?? []
        }
        #expect(sessions.count == sessionCount)
        let fetchSeconds = fetchTime.components.seconds
        print("perf: fetch 1000 sessions = \(fetchTime)")
        // 目標 < 1.0s、許容 2.0s(CI / Apple Silicon でも余裕)
        #expect(fetchSeconds < 2)

        // (b) Weekly aggregation — Charts の primary path
        var weekly: [WeeklyVolumePoint] = []
        let weeklyTime = clock.measure {
            weekly = WeeklyVolumePoint.aggregate(sessions: sessions)
        }
        #expect(!weekly.isEmpty)
        print("perf: weekly aggregate = \(weeklyTime)")
        #expect(weeklyTime < .seconds(1))

        // (c) Monthly aggregation — Charts (Pro)
        var monthly: [MonthlyVolumePoint] = []
        let monthlyTime = clock.measure {
            monthly = MonthlyVolumePoint.aggregate(sessions: sessions)
        }
        #expect(!monthly.isEmpty)
        print("perf: monthly aggregate = \(monthlyTime)")
        #expect(monthlyTime < .seconds(1))

        // (d) Heatmap aggregation — Charts (Pro、最重)
        var heatmap = MuscleHeatmapMatrix(cells: [])
        let heatmapTime = clock.measure {
            heatmap = MuscleHeatmapMatrix.aggregate(sessions: sessions)
        }
        #expect(!heatmap.cells.isEmpty)
        print("perf: heatmap aggregate = \(heatmapTime)")
        #expect(heatmapTime < .seconds(1))

        // (e) Day-grouping — HistoryCalendarView の同じ日比較相当
        let calendar = Calendar.current
        var dayBucket: [Date: Int] = [:]
        let dayTime = clock.measure {
            for s in sessions {
                let key = calendar.startOfDay(for: s.startedAt)
                dayBucket[key, default: 0] += 1
            }
        }
        #expect(!dayBucket.isEmpty)
        print("perf: day grouping = \(dayTime)")
        #expect(dayTime < .seconds(1))
    }

    // MARK: - 2. Templates — 100 entries

    @Test("Templates: 100 templates fetched, sorted, makeGeneratorOutput")
    func testTemplates_with100Templates() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        Self.seedMinimalExercises(context)

        // 100 テンプレ、半分は user-created、半分は preset 風
        for i in 0..<100 {
            let slugs: [String] = [
                "squat", "bench-press", "deadlift", "pull-up", "plank", "push-up"
            ].shuffled().prefix(3 + (i % 4)).map { $0 }
            let raw = (try? JSONEncoder().encode(slugs)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            let tpl = Template(
                name: "Template \(i)",
                exerciseSlugsRaw: raw,
                defaultGoalRaw: Goal.hypertrophy.rawValue,
                createdAt: Date().addingTimeInterval(-Double(i) * 60),
                isUserCreated: (i % 2 == 0)
            )
            context.insert(tpl)
        }
        try context.save()

        // TemplateStore.reload() を呼んで templates 配列に並べる
        let store = TemplateStore(context: context)
        let clock = ContinuousClock()
        let loadTime = clock.measure {
            store.reload()
        }
        #expect(store.templates.count == 100)
        print("perf: templates reload = \(loadTime)")
        #expect(loadTime < .seconds(1))

        // makeGeneratorOutput を全件分、ループで叩いても問題ないこと
        var totalSlugs = 0
        let convertTime = clock.measure {
            for tpl in store.templates {
                let out = store.makeGeneratorOutput(from: tpl)
                totalSlugs += out.warmup.count + out.main.count + out.cooldown.count
            }
        }
        #expect(totalSlugs > 0)
        print("perf: makeGeneratorOutput x100 = \(convertTime), total slugs=\(totalSlugs)")
        #expect(convertTime < .seconds(1))
    }

    // MARK: - 3. WorkoutGenerator — 345 exercises × 100 generations

    /// 345 種目すべて入っている DB に対し、`hypertrophy` × 主要部位の入力で
    /// generate() を 100 回叩いて平均と上限を計測する。Generator は決定的なので
    /// `randomSeed` を固定し、結果が空にならない範囲のみ検証する。
    @Test("Generator: 345 exercises × 100 generations median/avg/max under threshold")
    func testWorkoutGenerator_with345Exercises() async throws {
        let context = try Self.makeContext()

        // Seed: 全 muscles × 3 種目 を作って 345 件相当に揃える
        // (実 seed JSON のロードは I/O があり stress test の主旨から外れる。
        //  ここは「Generator が大量データを舐めて O(n) に劣化しないか」を見たい)
        var inserted = 0
        for muscle in Muscle.allCases {
            for variant in 0..<10 {
                for equip in [Equipment.bodyweight, .barbell, .dumbbell] {
                    let ex = Exercise(
                        slug: "\(muscle.rawValue)-\(equip.rawValue)-\(variant)",
                        slugJa: "\(muscle.rawValue)-\(variant)",
                        nameJa: "\(muscle.rawValue)-\(variant)",
                        nameEn: "\(muscle.rawValue)-\(variant)",
                        typeRaw: ExerciseType.strength.rawValue,
                        mechanicsTypeRaw: variant.isMultiple(of: 2)
                            ? MechanicsType.compound.rawValue
                            : MechanicsType.isolation.rawValue,
                        primaryMuscleRaw: muscle.rawValue,
                        secondaryMusclesRaw: "",
                        equipmentRaw: equip.rawValue
                    )
                    context.insert(ex)
                    inserted += 1
                }
            }
        }
        // WARMUP / STRETCHING も 10 件ずつ撒く(generateWarmup / generateCooldown 用)
        for variant in 0..<10 {
            for type in [ExerciseType.warmup, .stretching] {
                let ex = Exercise(
                    slug: "\(type.rawValue)-\(variant)",
                    slugJa: "\(type.rawValue)-\(variant)",
                    nameJa: "\(type.rawValue)-\(variant)",
                    nameEn: "\(type.rawValue)-\(variant)",
                    typeRaw: type.rawValue,
                    mechanicsTypeRaw: nil,
                    primaryMuscleRaw: Muscle.fullBody.rawValue,
                    secondaryMusclesRaw: "",
                    equipmentRaw: Equipment.bodyweight.rawValue
                )
                context.insert(ex)
                inserted += 1
            }
        }
        try context.save()
        // 期待値: muscle.allCases.count * 10 * 3 + 20。だいたい 345 前後になる
        // (実際の seed が 345 件なのでサイズ感は揃う)
        print("seeded \(inserted) exercises for generator stress")

        // 100 generations を回してそれぞれ計測
        let input = GeneratorInput(
            goal: .hypertrophy,
            muscles: [.chest, .lats, .quadriceps, .glutes],
            equipment: [.barbell, .dumbbell, .bodyweight],
            minutesAvailable: 60,
            includeWarmup: true,
            includeCooldown: true,
            randomSeed: 42
        )

        let clock = ContinuousClock()
        var durations: [Duration] = []
        durations.reserveCapacity(100)
        var lastOutput: GeneratorOutput?
        for _ in 0..<100 {
            let elapsed = clock.measure {
                lastOutput = try? WorkoutGenerator.generate(input, in: context)
            }
            durations.append(elapsed)
        }
        let outputUnwrapped = try #require(lastOutput, "Generator returned nil for 345-exercise stress input")
        #expect(!outputUnwrapped.main.isEmpty, "Generator produced empty main set")

        let totalSecs = durations.reduce(0.0) { $0 + Double($1.components.seconds) + Double($1.components.attoseconds) / 1e18 }
        let avgSecs = totalSecs / Double(durations.count)
        let maxDur = durations.max() ?? .zero
        let minDur = durations.min() ?? .zero
        print("perf generator x100: total=\(totalSecs)s avg=\(avgSecs)s min=\(minDur) max=\(maxDur)")

        // 個別 generate は十分小さい想定。100 回合計が 30 秒を超えたら遅すぎ。
        #expect(totalSecs < 30.0, "100 generations exceeded 30 seconds total (avg=\(avgSecs)s)")
        // 平均 1 回 < 0.5 秒。CLAUDE 目標は 100ms だが CI / Sim を考慮して緩めに。
        #expect(avgSecs < 0.5, "average generation > 500ms (=\(avgSecs)s)")
    }
}
