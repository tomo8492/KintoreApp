// MARK: - CSVImporter+Builder
// CSVImporter の補助型。ロングフォーマットを 1 種目に再構成する責務を切り出す。
// CLAUDE.md "1ファイル300行超で分割" 規約により別ファイル化。

import Foundation

extension CSVImporter {

    // MARK: - 列インデックス

    /// CSV ヘッダ → 列番号のマッピング。workout-cool 標準カラム名に対応する。
    struct ColumnIndex: Sendable {
        enum Column: String, CaseIterable {
            case id              = "id"
            case slug            = "slug"
            case nameEn          = "name_en"
            case nameJa          = "name_ja"
            case descriptionEn   = "description_en"
            case descriptionJa   = "description_ja"
            case introductionEn  = "introduction_en"
            case introductionJa  = "introduction_ja"
            case attributeName   = "attribute_name"
            case attributeValue  = "attribute_value"
        }

        private let map: [Column: Int]

        init(header: [String]) {
            var m: [Column: Int] = [:]
            for (idx, raw) in header.enumerated() {
                let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if let column = Column(rawValue: key) {
                    m[column] = idx
                }
            }
            self.map = m
        }

        /// 必須列(id / slug / attribute_name / attribute_value)が揃っているか。
        /// 名前列は片方が欠けても他方で代替できるので緩める。
        var isValid: Bool {
            map[.id] != nil && map[.slug] != nil
                && map[.attributeName] != nil && map[.attributeValue] != nil
        }

        func value(_ column: Column, in row: [String]) -> String? {
            guard let idx = map[column], idx < row.count else { return nil }
            let v = row[idx].trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? nil : v
        }
    }

    // MARK: - 種目ビルダー

    /// 1 種目分の中間表現。ロングフォーマット行を読みながら状態を蓄積し、最後に build() で固める。
    struct ExerciseBuilder {
        let legacyCsvId: Int?
        let slug: String

        var nameEn: String = ""
        var nameJa: String = ""
        var descriptionEn: String = ""
        var descriptionJa: String = ""
        var introductionEn: String = ""
        var introductionJa: String = ""

        var typeRaw: String?
        var mechanicsTypeRaw: String?
        var primaryMuscleRaw: String?
        var secondaryMuscles: [String] = []
        var equipment: [String] = []

        mutating func merge(
            nameEn: String?,
            nameJa: String?,
            descriptionEn: String?,
            descriptionJa: String?,
            introductionEn: String?,
            introductionJa: String?
        ) {
            if self.nameEn.isEmpty, let v = nameEn { self.nameEn = v }
            if self.nameJa.isEmpty, let v = nameJa { self.nameJa = v }
            if self.descriptionEn.isEmpty, let v = descriptionEn { self.descriptionEn = v }
            if self.descriptionJa.isEmpty, let v = descriptionJa { self.descriptionJa = v }
            if self.introductionEn.isEmpty, let v = introductionEn { self.introductionEn = v }
            if self.introductionJa.isEmpty, let v = introductionJa { self.introductionJa = v }
        }

        /// `attribute_name` / `attribute_value` の 1 行を取り込む。
        /// - Returns: 既知属性なら true、未知 / 不正な値なら false。
        mutating func applyAttribute(name: String, value: String) -> Bool {
            let key = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
            switch key {
            case "TYPE":
                guard let normalized = AttributeNormalizer.exerciseType(raw) else { return false }
                typeRaw = normalized
                return true
            case "MECHANICS_TYPE":
                guard let normalized = AttributeNormalizer.mechanicsType(raw) else { return false }
                mechanicsTypeRaw = normalized
                return true
            case "PRIMARY_MUSCLE":
                guard let normalized = AttributeNormalizer.muscle(raw) else { return false }
                primaryMuscleRaw = normalized
                return true
            case "SECONDARY_MUSCLE":
                guard let normalized = AttributeNormalizer.muscle(raw) else { return false }
                if !secondaryMuscles.contains(normalized) { secondaryMuscles.append(normalized) }
                return true
            case "EQUIPMENT":
                guard let normalized = AttributeNormalizer.equipment(raw) else { return false }
                if !equipment.contains(normalized) { equipment.append(normalized) }
                return true
            default:
                return false
            }
        }

        /// 必須属性(type, primaryMuscle)が揃っているときのみ ParsedExercise を返す。
        func build() -> ParsedExercise? {
            guard let typeRaw, let primaryMuscleRaw else { return nil }
            // 名前は ja/en どちらか必須。両方欠けたら捨てる。
            if nameEn.isEmpty && nameJa.isEmpty { return nil }
            return ParsedExercise(
                slug: slug,
                slugJa: nameJa.isEmpty ? slug : slug,
                legacyCsvId: legacyCsvId,
                nameEn: nameEn.isEmpty ? slug : nameEn,
                nameJa: nameJa.isEmpty ? nameEn : nameJa,
                descriptionEn: descriptionEn,
                descriptionJa: descriptionJa,
                introductionEn: introductionEn,
                introductionJa: introductionJa,
                typeRaw: typeRaw,
                mechanicsTypeRaw: mechanicsTypeRaw,
                primaryMuscleRaw: primaryMuscleRaw,
                secondaryMusclesRaw: secondaryMuscles.joined(separator: ","),
                equipmentRaw: equipment.joined(separator: ",")
            )
        }
    }
}

// MARK: - ParsedExercise
// CSV / JSON どちらの importer からも組み立てられる中間 DTO。
// SwiftData の Exercise 生成 / 既存 Exercise への上書きの両方を担う。

struct ParsedExercise: Sendable, Equatable {
    let slug: String
    let slugJa: String
    let legacyCsvId: Int?
    let nameEn: String
    let nameJa: String
    let descriptionEn: String
    let descriptionJa: String
    let introductionEn: String
    let introductionJa: String
    let typeRaw: String
    let mechanicsTypeRaw: String?
    let primaryMuscleRaw: String
    let secondaryMusclesRaw: String
    let equipmentRaw: String

    func makeEntity() -> Exercise {
        Exercise(
            slug: slug,
            slugJa: slugJa,
            legacyCsvId: legacyCsvId,
            nameJa: nameJa,
            nameEn: nameEn,
            descriptionJa: descriptionJa,
            descriptionEn: descriptionEn,
            introductionJa: introductionJa,
            introductionEn: introductionEn,
            typeRaw: typeRaw,
            mechanicsTypeRaw: mechanicsTypeRaw,
            primaryMuscleRaw: primaryMuscleRaw,
            secondaryMusclesRaw: secondaryMusclesRaw,
            equipmentRaw: equipmentRaw
        )
    }

    /// 既存 Exercise に CSV 由来フィールドだけを上書きする。
    /// step 画像 / cautions / thumbnail などの v1 同梱メタは保持する。
    func apply(to entity: Exercise) {
        entity.slugJa = slugJa
        if let legacyCsvId { entity.legacyCsvId = legacyCsvId }
        entity.nameJa = nameJa
        entity.nameEn = nameEn
        entity.descriptionJa = descriptionJa
        entity.descriptionEn = descriptionEn
        entity.introductionJa = introductionJa
        entity.introductionEn = introductionEn
        entity.typeRaw = typeRaw
        entity.mechanicsTypeRaw = mechanicsTypeRaw
        entity.primaryMuscleRaw = primaryMuscleRaw
        entity.secondaryMusclesRaw = secondaryMusclesRaw
        entity.equipmentRaw = equipmentRaw
    }
}
