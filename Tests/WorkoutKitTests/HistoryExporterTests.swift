// MARK: - HistoryExporterTests
// CLAUDE.md §9.1 / §1.1 F-06 準拠。
// HistoryExporter で書き出した CSV を HistoryExporter.parseCSV で読み戻し、
// 元データと一致するか(ラウンドトリップ)を確認する。
// SwiftData の関係プロパティを安全に扱うため in-memory ModelContainer を作る。

import Foundation
import Testing
import SwiftData
@testable import WorkoutKit

@Suite("HistoryExporter")
@MainActor
struct HistoryExporterTests {

    // MARK: - Container

    private static func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Fixtures

    private func makeExercise(in context: ModelContext, slug: String) -> Exercise {
        let exercise = Exercise(
            slug: slug,
            slugJa: slug,
            nameJa: slug,
            nameEn: slug,
            typeRaw: ExerciseType.strength.rawValue,
            primaryMuscleRaw: Muscle.chest.rawValue
        )
        context.insert(exercise)
        return exercise
    }

    private func makeSession(
        in context: ModelContext,
        id: UUID,
        startedAt: Date,
        notes: String = "leg day, felt strong",
        sets: [(order: Int, slug: String, reps: Int, weight: Double, rpe: Double?, rest: Int)]
    ) -> WorkoutSession {
        let session = WorkoutSession(
            id: id,
            startedAt: startedAt,
            finishedAt: startedAt.addingTimeInterval(60 * 30),
            timeZoneIdentifier: "UTC",
            notes: notes,
            goalRaw: Goal.hypertrophy.rawValue,
            includesWarmup: true,
            includesCooldown: false,
            isManualEntry: false
        )
        context.insert(session)
        for item in sets {
            let set = ExerciseSet(
                order: item.order,
                sectionRaw: SessionSection.main.rawValue,
                reps: item.reps,
                weightKg: item.weight,
                rpe: item.rpe,
                restSeconds: item.rest,
                completedAt: startedAt.addingTimeInterval(Double(item.order) * 90),
                exercise: makeExercise(in: context, slug: item.slug),
                session: session
            )
            context.insert(set)
        }
        return session
    }

    // MARK: - Tests

    @Test("ヘッダ列が CLAUDE.md 規約どおりの順で出力される")
    func headerIsStable() {
        let csv = HistoryExporter.exportCSV([])
        var stripped = csv
        if stripped.starts(with: [0xEF, 0xBB, 0xBF]) {
            stripped.removeFirst(3)
        }
        let text = String(data: stripped, encoding: .utf8) ?? ""
        let firstLine = text.split(separator: "\n").first.map(String.init) ?? ""
        let cells = CSVParser.parse(firstLine).first ?? []
        #expect(cells == HistoryExporter.columns)
    }

    @Test("セッションを書き出してパースし、元データと一致する(ラウンドトリップ)")
    func roundTripPreservesValues() throws {
        let container = try Self.makeContainer()
        let context = container.mainContext

        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let id = UUID()
        let session = makeSession(
            in: context,
            id: id,
            startedAt: started,
            sets: [
                (1, "bench-press", 10, 60.0, 7.5, 90),
                (2, "bench-press-2", 8, 65.0, 8.0, 120),
                (3, "incline-press", 12, 22.5, nil, 60)
            ]
        )

        let exported = HistoryExporter.exportCSV([session])
        let parsed = HistoryExporter.parseCSV(exported)

        #expect(parsed.count == 1)
        let read = try #require(parsed.first)
        #expect(read.sessionId == id)
        #expect(read.timeZoneIdentifier == "UTC")
        #expect(read.goalRaw == Goal.hypertrophy.rawValue)
        #expect(read.includesWarmup == true)
        #expect(read.includesCooldown == false)
        #expect(read.isManualEntry == false)
        #expect(read.notes == "leg day, felt strong")
        #expect(read.sets.count == 3)

        let sortedSets = read.sets.sorted { $0.order < $1.order }
        let first = sortedSets[0]
        #expect(first.order == 1)
        #expect(first.exerciseSlug == "bench-press")
        #expect(first.reps == 10)
        #expect(abs(first.weightKg - 60.0) < 0.001)
        #expect(first.rpe.map { abs($0 - 7.5) < 0.001 } ?? false)
        #expect(first.restSeconds == 90)

        // 3本目は rpe が nil
        let third = sortedSets[2]
        #expect(third.rpe == nil)
        #expect(third.exerciseSlug == "incline-press")
    }

    @Test("複数セッションを順序保持して出力する")
    func multipleSessionsKeepOrder() throws {
        let container = try Self.makeContainer()
        let context = container.mainContext

        let session1 = makeSession(
            in: context,
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            sets: [(1, "squat", 5, 100, 8.0, 180)]
        )
        let session2 = makeSession(
            in: context,
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 1_700_086_400),
            sets: [(1, "deadlift", 3, 140, 9.0, 240)]
        )

        let exported = HistoryExporter.exportCSV([session1, session2])
        let parsed = HistoryExporter.parseCSV(exported)
        #expect(parsed.count == 2)
        #expect(parsed[0].sessionId == session1.id)
        #expect(parsed[1].sessionId == session2.id)
        #expect(parsed[1].sets.first?.exerciseSlug == "deadlift")
    }

    @Test("セット 0 のセッションも 1 行残る")
    func sessionWithoutSetsKeepsRow() throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            timeZoneIdentifier: "UTC",
            notes: "",
            goalRaw: Goal.hypertrophy.rawValue
        )
        context.insert(session)
        let exported = HistoryExporter.exportCSV([session])
        let parsed = HistoryExporter.parseCSV(exported)
        #expect(parsed.count == 1)
        #expect(parsed.first?.sets.isEmpty == true)
    }

    @Test("notes に改行・引用符・カンマが含まれていても壊れない")
    func notesEscapingSurvivesRoundTrip() throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let session = makeSession(
            in: context,
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            notes: "line1\n\"quoted\", with comma",
            sets: [(1, "row", 8, 50, nil, 60)]
        )
        let exported = HistoryExporter.exportCSV([session])
        let parsed = HistoryExporter.parseCSV(exported)
        #expect(parsed.first?.notes == "line1\n\"quoted\", with comma")
    }
}
