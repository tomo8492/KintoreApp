// MARK: - TemplateSeeder
// CLAUDE.md §1.1 F-05 / §-1.10 / §4.1 準拠。
// 初回起動時に 3 プリセット(PPL / Upper-Lower / Full-Body)を SwiftData に投入する。
//
// 冪等性の戦略:
//   UserDefaults に "templates.presetsSeeded.v1" フラグを立てる。
//   Pro ユーザーがプリセットを編集・削除しても再生成しない(これにより
//   「リネーム→重複生成」事故を防ぐ)。新プリセットを追加したくなったら
//   キーを v2 に上げる。
//
// プリセットの中身は Resources/exercises_seed.json に存在する slug
// のみで構成する(B1 の Generator が後で warmup/cooldown を補強する想定)。
// 名前は英語の安定識別子で保存し、表示時に View 側で Localizable.xcstrings
// 経由で日本語化する(`TemplatesView.localizedDisplayName(for:)`)。

import Foundation
import SwiftData
import OSLog

enum TemplateSeeder {
    /// 一度 seed したらフラグを立て、二度と再投入しない。
    static let seededFlagKey = "templates.presetsSeeded.v1"

    /// プリセット定義。中身は exercises_seed.json の slug に存在するもののみで構成。
    /// CLAUDE.md §-1.10 で v1.0 出荷条件として 150 種目を seed する想定だが、
    /// 現時点(P0) は 3 種目しか入っていないため、テンプレもそれに合わせて薄い構成。
    /// 種目数が増えたタイミングで `seededFlagKey` を v2 に上げて再 seed する。
    struct Preset: Sendable {
        /// SwiftData に保存される安定識別子。英語固定。
        let stableName: String
        let goal: Goal
        let slugs: [String]
    }

    static let presets: [Preset] = [
        // PPL: Push Day を代表させる(Pull/Legs は exercise が増えてから)
        Preset(
            stableName: "Push Day (PPL)",
            goal: .hypertrophy,
            slugs: ["push-up"]
        ),
        // Upper/Lower: Lower Day を代表させる
        Preset(
            stableName: "Lower Body (Upper/Lower)",
            goal: .hypertrophy,
            slugs: ["barbell-back-squat", "plank"]
        ),
        // Full Body: 全身一周
        Preset(
            stableName: "Full Body",
            goal: .hypertrophy,
            slugs: ["barbell-back-squat", "push-up", "plank"]
        )
    ]

    // MARK: - Seed

    /// 初回起動時に1回だけプリセットを投入する。
    /// - Returns: 新規に挿入した件数。既に seed 済みなら 0。
    @discardableResult
    static func seedIfNeeded(
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws -> Int {
        if defaults.bool(forKey: seededFlagKey) {
            Logger.data.debug("templates seed already applied, skipping")
            return 0
        }

        var inserted = 0
        for preset in presets {
            let raw = try encodeSlugs(preset.slugs)
            let template = Template(
                name: preset.stableName,
                exerciseSlugsRaw: raw,
                defaultGoalRaw: preset.goal.rawValue,
                isUserCreated: false
            )
            context.insert(template)
            inserted += 1
        }

        if context.hasChanges {
            try context.save()
        }
        defaults.set(true, forKey: seededFlagKey)
        Logger.data.info("seeded \(inserted) preset templates")
        return inserted
    }

    // MARK: - Helpers

    private static func encodeSlugs(_ slugs: [String]) throws -> String {
        let data = try JSONEncoder().encode(slugs)
        guard let string = String(data: data, encoding: .utf8) else {
            throw AppError.dataCorruption("preset slug encode failed")
        }
        return string
    }
}
