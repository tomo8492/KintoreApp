// MARK: - JSONImporter
// CLAUDE.md §1.1 F-06 / §4.2.1 準拠。
// 内部スキーマ(WorkoutKit が export した JSON)をそのまま取り込むためのインポータ。
// Exercise / WorkoutSession / ExerciseSet を扱う。
//
// 形:
// {
//   "exercises": [ ParsedExercise 互換 ],
//   "sessions":  [ SessionDTO ]
// }
// 既存 slug / id があるレコードはスキップ(冪等)。

import Foundation
import SwiftData
import OSLog

enum JSONImporter {

    // MARK: - DTO

    struct Payload: Codable, Sendable {
        var exercises: [ExerciseDTO]?
        var sessions: [SessionDTO]?
    }

    struct ExerciseDTO: Codable, Sendable {
        let slug: String
        let slugJa: String?
        let legacyCsvId: Int?
        let nameEn: String
        let nameJa: String
        let descriptionEn: String?
        let descriptionJa: String?
        let introductionEn: String?
        let introductionJa: String?
        let typeRaw: String
        let mechanicsTypeRaw: String?
        let primaryMuscleRaw: String
        let secondaryMusclesRaw: String?
        let equipmentRaw: String?
    }

    struct SessionDTO: Codable, Sendable {
        let id: UUID
        let startedAt: Date
        let finishedAt: Date?
        let timeZoneIdentifier: String?
        let notes: String?
        let goalRaw: String
        let includesWarmup: Bool?
        let includesCooldown: Bool?
        let isManualEntry: Bool?
        let sets: [SetDTO]?
    }

    struct SetDTO: Codable, Sendable {
        let id: UUID
        let order: Int
        let sectionRaw: String?
        let exerciseSlug: String?
        let reps: Int
        let weightKg: Double
        let rpe: Double?
        let restSeconds: Int?
        let durationSeconds: Int?
        let completedAt: Date?
    }

    // MARK: - Result

    struct ImportResult: Sendable, Equatable {
        var insertedExercises: Int
        var updatedExercises: Int
        var insertedSessions: Int
        var skippedSessions: Int
    }

    // MARK: - 公開 API

    /// JSON を読み、Exercise / WorkoutSession を SwiftData に取り込む。
    /// 失敗(ファイル破損)は AppError.importFailed に正規化して投げる。
    @MainActor
    static func importAll(
        from data: Data,
        into context: ModelContext
    ) throws -> ImportResult {
        let payload = try decode(data)

        var insertedEx = 0
        var updatedEx = 0
        var insertedSe = 0
        var skippedSe = 0

        for dto in payload.exercises ?? [] {
            switch try upsertExercise(dto, in: context) {
            case .inserted: insertedEx += 1
            case .updated: updatedEx += 1
            }
        }
        for dto in payload.sessions ?? [] {
            if try insertSession(dto, in: context) {
                insertedSe += 1
            } else {
                skippedSe += 1
            }
        }

        if context.hasChanges {
            try context.save()
        }
        Logger.importer.info(
            "JSON imported: ex(+\(insertedEx)/~\(updatedEx)) sessions(+\(insertedSe)/skip\(skippedSe))"
        )
        return ImportResult(
            insertedExercises: insertedEx,
            updatedExercises: updatedEx,
            insertedSessions: insertedSe,
            skippedSessions: skippedSe
        )
    }

    /// Exercise だけを取り込む薄いラッパ(UI から個別ボタン用)。
    @MainActor
    static func importExercises(
        from data: Data,
        into context: ModelContext
    ) throws -> ImportResult {
        let payload = try decode(data)
        var inserted = 0
        var updated = 0
        for dto in payload.exercises ?? [] {
            switch try upsertExercise(dto, in: context) {
            case .inserted: inserted += 1
            case .updated:  updated += 1
            }
        }
        if context.hasChanges { try context.save() }
        return ImportResult(
            insertedExercises: inserted,
            updatedExercises: updated,
            insertedSessions: 0,
            skippedSessions: 0
        )
    }

    // MARK: - Internal

    private enum UpsertOutcome { case inserted, updated }

    private static func decode(_ data: Data) throws -> Payload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(Payload.self, from: data)
        } catch {
            Logger.importer.error("JSON decode failed: \(String(describing: error))")
            throw AppError.importFailed(reason: "json-decode-failed")
        }
    }

    @MainActor
    private static func upsertExercise(
        _ dto: ExerciseDTO,
        in context: ModelContext
    ) throws -> UpsertOutcome {
        let parsed = ParsedExercise(
            slug: dto.slug,
            slugJa: dto.slugJa ?? dto.slug,
            legacyCsvId: dto.legacyCsvId,
            nameEn: dto.nameEn,
            nameJa: dto.nameJa,
            descriptionEn: dto.descriptionEn ?? "",
            descriptionJa: dto.descriptionJa ?? "",
            introductionEn: dto.introductionEn ?? "",
            introductionJa: dto.introductionJa ?? "",
            typeRaw: dto.typeRaw,
            mechanicsTypeRaw: dto.mechanicsTypeRaw,
            primaryMuscleRaw: dto.primaryMuscleRaw,
            secondaryMusclesRaw: dto.secondaryMusclesRaw ?? "",
            equipmentRaw: dto.equipmentRaw ?? ""
        )
        let slug = parsed.slug
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.slug == slug })
        if let existing = try context.fetch(descriptor).first {
            if existing.isUserCreated {
                // ユーザー作成種目は上書きしない
                return .updated
            }
            parsed.apply(to: existing)
            return .updated
        } else {
            context.insert(parsed.makeEntity())
            return .inserted
        }
    }

    @MainActor
    private static func insertSession(
        _ dto: SessionDTO,
        in context: ModelContext
    ) throws -> Bool {
        let id = dto.id
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })
        if !(try context.fetch(descriptor)).isEmpty {
            return false
        }
        let session = WorkoutSession(
            id: dto.id,
            startedAt: dto.startedAt,
            finishedAt: dto.finishedAt,
            timeZoneIdentifier: dto.timeZoneIdentifier ?? TimeZone.current.identifier,
            notes: dto.notes ?? "",
            goalRaw: dto.goalRaw,
            includesWarmup: dto.includesWarmup ?? true,
            includesCooldown: dto.includesCooldown ?? true,
            isManualEntry: dto.isManualEntry ?? false
        )
        context.insert(session)

        for setDTO in dto.sets ?? [] {
            let set = ExerciseSet(
                id: setDTO.id,
                order: setDTO.order,
                sectionRaw: setDTO.sectionRaw ?? SessionSection.main.rawValue,
                reps: setDTO.reps,
                weightKg: setDTO.weightKg,
                rpe: setDTO.rpe,
                restSeconds: setDTO.restSeconds ?? 60,
                durationSeconds: setDTO.durationSeconds,
                completedAt: setDTO.completedAt,
                exercise: try fetchExercise(slug: setDTO.exerciseSlug, in: context),
                session: session
            )
            context.insert(set)
        }
        return true
    }

    @MainActor
    private static func fetchExercise(slug: String?, in context: ModelContext) throws -> Exercise? {
        guard let slug, !slug.isEmpty else { return nil }
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.slug == slug })
        return try context.fetch(descriptor).first
    }
}
