// MARK: - ExerciseSeeder
// CLAUDE.md §4.1 / §-1.10 準拠。
// 初回起動時に Resources/exercises_seed.json を読み、SwiftData に投入する。
// 既に slug が存在する種目はスキップ(再起動時の二重挿入防止)。

import Foundation
import SwiftData
import OSLog

enum ExerciseSeeder {
    /// E1: seed の「世代」。JSON の内容やバックフィル対象フィールドを変更したら
    /// この値をインクリメントすること。インクリメントすると、次回起動時に
    /// 「既に seed 済みだから何もしない」高速パスをバイパスして、
    /// フル経路(JSON デコード + 345 件 upsert/backfill)がもう一度走る。
    static let seedVersion = 1
    /// 上記バージョンを保存する UserDefaults キー。
    static let seedVersionDefaultsKey = "workoutkit.exerciseSeed.version"

    /// JSON の1要素に対応する DTO。Exercise への詰め替えはここで集約する。
    struct SeedRecord: Decodable, Sendable {
        let slug: String
        let slugJa: String
        let legacyCsvId: Int?
        let nameJa: String
        let nameEn: String
        let descriptionJa: String?
        let descriptionEn: String?
        let introductionJa: String?
        let introductionEn: String?
        let typeRaw: String
        let mechanicsTypeRaw: String?
        let primaryMuscleRaw: String
        let secondaryMusclesRaw: String?
        let equipmentRaw: String?
        let stepImagesRaw: String?
        let stepTextJaRaw: String?
        let stepTextEnRaw: String?
        let cautionsJa: String?
        let cautionsEn: String?
        /// 「よくある間違い」(改行区切り、optional)。Exercise モデルに同名で保存。
        let commonMistakesJa: String?
        let commonMistakesEn: String?
        let youtubeSearchQuery: String?
        let thumbnailFileName: String?
    }

    /// メインバンドルから seed JSON を読み、未登録のものだけ挿入する。
    /// - Returns: 新規に挿入した件数
    @discardableResult
    static func seedIfNeeded(
        in context: ModelContext,
        bundle: Bundle = .main,
        resourceName: String = "exercises_seed",
        resourceExtension: String = "json",
        defaults: UserDefaults = .standard
    ) throws -> Int {
        // E1: 起動高速パス。既にこのバージョンで seed 済み、かつストアに Exercise が
        // 1 件以上あるなら、763KB の JSON デコード + 345 回の FetchDescriptor を
        // まるごとスキップする。バージョンが古い(= seedVersion をインクリメントした)
        // 場合はここを通らず、下のフル経路(upsert/backfill)が走る。
        let storedVersion = defaults.integer(forKey: seedVersionDefaultsKey)
        if storedVersion == seedVersion {
            var existenceCheck = FetchDescriptor<Exercise>()
            existenceCheck.fetchLimit = 1
            let hasAny = !(try context.fetch(existenceCheck)).isEmpty
            if hasAny {
                Logger.data.info("seed skipped: already seeded at version \(seedVersion)")
                return 0
            }
        }

        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            Logger.data.error("seed file not found in bundle: \(resourceName).\(resourceExtension)")
            throw AppError.dataCorruption("seed file missing")
        }

        let data = try Data(contentsOf: url)
        let records = try JSONDecoder().decode([SeedRecord].self, from: data)

        var inserted = 0
        for record in records {
            let slug = record.slug
            let descriptor = FetchDescriptor<Exercise>(
                predicate: #Predicate { $0.slug == slug }
            )
            let existing = try context.fetch(descriptor)
            if let existingExercise = existing.first {
                // 既存ストアでは新規追加した optional フィールド
                // (commonMistakesJa/En)が nil のままなので、seed JSON 側に
                // 値があれば backfill する。これがないと、初回起動済みの端末で
                // 「よくある間違い」セクションが永久に空になる。
                backfillNewFields(into: existingExercise, from: record)
                continue
            }

            let exercise = Exercise(
                slug: record.slug,
                slugJa: record.slugJa,
                legacyCsvId: record.legacyCsvId,
                nameJa: record.nameJa,
                nameEn: record.nameEn,
                descriptionJa: record.descriptionJa ?? "",
                descriptionEn: record.descriptionEn ?? "",
                introductionJa: record.introductionJa ?? "",
                introductionEn: record.introductionEn ?? "",
                typeRaw: record.typeRaw,
                mechanicsTypeRaw: record.mechanicsTypeRaw,
                primaryMuscleRaw: record.primaryMuscleRaw,
                secondaryMusclesRaw: record.secondaryMusclesRaw ?? "",
                equipmentRaw: record.equipmentRaw ?? "",
                stepImagesRaw: record.stepImagesRaw ?? "[]",
                stepTextJaRaw: record.stepTextJaRaw ?? "[]",
                stepTextEnRaw: record.stepTextEnRaw ?? "[]",
                cautionsJa: record.cautionsJa ?? "",
                cautionsEn: record.cautionsEn ?? "",
                commonMistakesJa: record.commonMistakesJa,
                commonMistakesEn: record.commonMistakesEn,
                youtubeSearchQuery: record.youtubeSearchQuery,
                thumbnailFileName: record.thumbnailFileName
            )
            context.insert(exercise)
            inserted += 1
        }

        if context.hasChanges {
            try context.save()
        }
        // フル経路が最後まで成功したときだけバージョンを記録する。
        // 途中で throw した場合は保存されないため、次回起動時にまた
        // フル経路が走り直す(=中途半端な状態を「seed 済み」と誤認しない)。
        defaults.set(seedVersion, forKey: seedVersionDefaultsKey)
        Logger.data.info("seeded \(inserted) new exercises (total records: \(records.count))")
        return inserted
    }

    /// 既存 Exercise に対して、後から SchemaV1 に追加された optional フィールドのみ backfill する。
    /// 上書きするのは現在 nil または空のときだけ(ユーザーが将来手動編集できるようにするため)。
    private static func backfillNewFields(into exercise: Exercise, from record: SeedRecord) {
        if (exercise.commonMistakesJa ?? "").isEmpty,
           let value = record.commonMistakesJa, !value.isEmpty {
            exercise.commonMistakesJa = value
        }
        if (exercise.commonMistakesEn ?? "").isEmpty,
           let value = record.commonMistakesEn, !value.isEmpty {
            exercise.commonMistakesEn = value
        }
    }
}
