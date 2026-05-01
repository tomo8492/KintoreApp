// MARK: - ExerciseSeeder
// CLAUDE.md §4.1 / §-1.10 準拠。
// 初回起動時に Resources/exercises_seed.json を読み、SwiftData に投入する。
// 既に slug が存在する種目はスキップ(再起動時の二重挿入防止)。

import Foundation
import SwiftData

enum ExerciseSeeder {
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
        resourceExtension: String = "json"
    ) throws -> Int {
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
            if !existing.isEmpty { continue }

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
                youtubeSearchQuery: record.youtubeSearchQuery,
                thumbnailFileName: record.thumbnailFileName
            )
            context.insert(exercise)
            inserted += 1
        }

        if context.hasChanges {
            try context.save()
        }
        Logger.data.info("seeded \(inserted) new exercises (total records: \(records.count))")
        return inserted
    }
}
