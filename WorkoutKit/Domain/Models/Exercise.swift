// MARK: - Exercise
// SwiftData モデル。CLAUDE.md §-1.2 / §4.2 準拠。
// 主キーは UUID ではなく `slug`(workout-cool 互換、CSV再インポート時に安定)。

import Foundation
import SwiftData

@Model
final class Exercise {
    // --- ID -----------------------------------------------------------
    /// 主キー(英語slug、例: "barbell-back-squat")。世界に1つだけの安定ID。
    /// CLAUDE.md §-1.2 規約により UUID は使わない。
    @Attribute(.unique) var slug: String
    /// 表示用の日本語slug(検索補助)。主キーではない。
    var slugJa: String
    /// workout-cool CSV 由来の数値ID(任意保持、突合用)。
    var legacyCsvId: Int?

    // --- 多言語フィールド --------------------------------------------
    var nameJa: String
    var nameEn: String
    /// HTML リッチテキスト。AttributedString で View 層がレンダリングする。
    var descriptionJa: String
    var descriptionEn: String
    /// 短い導入文(workout-cool の introduction 互換)。
    var introductionJa: String
    var introductionEn: String

    // --- 属性 ---------------------------------------------------------
    // workout-cool の attribute_name 5種を専用カラムに昇格(§4.2)。
    // SwiftData の @Model は enum を直接保持できないため rawValue を保存し、
    // 計算プロパティで型に戻す。

    /// `ExerciseType.rawValue` を保存。
    var typeRaw: String
    /// `MechanicsType.rawValue` を保存。STRETCHING/WARMUP 等は nil。
    var mechanicsTypeRaw: String?
    /// `Muscle.rawValue` を保存(主働筋、必ず1つ)。
    var primaryMuscleRaw: String
    /// 協働筋。`Muscle.rawValue` のカンマ区切り文字列(例: "lats,traps")。
    var secondaryMusclesRaw: String
    /// 必要器具。`Equipment.rawValue` のカンマ区切り文字列。
    var equipmentRaw: String

    // --- メディア(動画なし、ステップイラストベース) ----------------
    /// 開始/中間/終了など 3〜5枚のイラストファイル名を JSON 文字列で保持。
    /// 例: `["chest-press-1.png","chest-press-2.png","chest-press-3.png"]`
    var stepImagesRaw: String
    /// 各ステップの説明文(日本語)を JSON 配列文字列で保持。
    var stepTextJaRaw: String
    /// 各ステップの説明文(英語)。
    var stepTextEnRaw: String
    /// ありがちな誤フォーム等の注意点(改行区切り)。
    var cautionsJa: String
    var cautionsEn: String
    /// YouTube アプリへのDeep Link用検索クエリ(Pro機能)。
    var youtubeSearchQuery: String?
    /// ライブラリ一覧で使うサムネイルのファイル名。
    var thumbnailFileName: String?

    // --- メタ ---------------------------------------------------------
    var createdAt: Date
    /// ユーザーが追加したカスタム種目か(Pro 機能 customExercise)。
    var isUserCreated: Bool

    // --- 関連 ---------------------------------------------------------
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
    var sets: [ExerciseSet] = []

    // MARK: - Init

    init(
        slug: String,
        slugJa: String,
        legacyCsvId: Int? = nil,
        nameJa: String,
        nameEn: String,
        descriptionJa: String = "",
        descriptionEn: String = "",
        introductionJa: String = "",
        introductionEn: String = "",
        typeRaw: String,
        mechanicsTypeRaw: String? = nil,
        primaryMuscleRaw: String,
        secondaryMusclesRaw: String = "",
        equipmentRaw: String = "",
        stepImagesRaw: String = "[]",
        stepTextJaRaw: String = "[]",
        stepTextEnRaw: String = "[]",
        cautionsJa: String = "",
        cautionsEn: String = "",
        youtubeSearchQuery: String? = nil,
        thumbnailFileName: String? = nil,
        createdAt: Date = .now,
        isUserCreated: Bool = false
    ) {
        self.slug = slug
        self.slugJa = slugJa
        self.legacyCsvId = legacyCsvId
        self.nameJa = nameJa
        self.nameEn = nameEn
        self.descriptionJa = descriptionJa
        self.descriptionEn = descriptionEn
        self.introductionJa = introductionJa
        self.introductionEn = introductionEn
        self.typeRaw = typeRaw
        self.mechanicsTypeRaw = mechanicsTypeRaw
        self.primaryMuscleRaw = primaryMuscleRaw
        self.secondaryMusclesRaw = secondaryMusclesRaw
        self.equipmentRaw = equipmentRaw
        self.stepImagesRaw = stepImagesRaw
        self.stepTextJaRaw = stepTextJaRaw
        self.stepTextEnRaw = stepTextEnRaw
        self.cautionsJa = cautionsJa
        self.cautionsEn = cautionsEn
        self.youtubeSearchQuery = youtubeSearchQuery
        self.thumbnailFileName = thumbnailFileName
        self.createdAt = createdAt
        self.isUserCreated = isUserCreated
    }
}

// MARK: - Computed accessors
// rawValue を enum に戻すヘルパー。View / Generator 側はこれを使う。

extension Exercise {
    var type: ExerciseType {
        ExerciseType(rawValue: typeRaw) ?? .strength
    }

    var mechanicsType: MechanicsType? {
        guard let raw = mechanicsTypeRaw else { return nil }
        return MechanicsType(rawValue: raw)
    }

    var primaryMuscle: Muscle {
        Muscle(rawValue: primaryMuscleRaw) ?? .fullBody
    }

    var secondaryMuscles: [Muscle] {
        secondaryMusclesRaw
            .split(separator: ",")
            .compactMap { Muscle(rawValue: String($0)) }
    }

    var equipment: [Equipment] {
        equipmentRaw
            .split(separator: ",")
            .compactMap { Equipment(rawValue: String($0)) }
    }

    /// 現在のロケール言語コードに応じて nameJa / nameEn を返す。
    /// CLAUDE.md §-1.4 / §0.2 に従い、日本語(主)+ 英語の二択。
    /// それ以外のロケールでは英語にフォールバック。
    var localizedName: String {
        Locale.current.language.languageCode?.identifier == "ja" ? nameJa : nameEn
    }
}
