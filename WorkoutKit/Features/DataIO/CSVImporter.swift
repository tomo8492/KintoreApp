// MARK: - CSVImporter
// CLAUDE.md §1.1 F-06 / §4.2.1 / §-1.10 準拠。
// workout-cool 公式 CSV(ロングフォーマット)を読み Exercise として SwiftData に投入する。
//
// 入力フォーマット(workout-cool /data/sample-exercises.csv 参照):
//   id,slug,name_en,name_ja,description_en,description_ja,
//   introduction_en,introduction_ja,attribute_name,attribute_value
// 1 種目あたり N 行(attribute_name の組み合わせごとに 1 行)。
// `id` でグルーピングし、attribute_name → 5属性カラムへ詰め替える。

import Foundation
import SwiftData
import OSLog

enum CSVImporter {

    // MARK: - 公開 API

    struct ImportResult: Sendable, Equatable {
        var inserted: Int
        var updated: Int
        var skipped: Int
        var malformedRows: Int
    }

    /// CSV データを読み込み、ParsedExercise の配列に変換する(SwiftData に触らない pure 関数)。
    /// - Throws: ヘッダが致命的に欠損している場合は AppError.importFailed。
    ///   個別行の不正(必須カラム欠落 / 列挙値不正)はスキップしてログに残す。
    static func parseExercises(from data: Data) throws -> [ParsedExercise] {
        // HistoryExporter は Excel 互換のため UTF-8 BOM を付加する。再インポート時に
        // 先頭セルへ BOM が混入しないよう、CSVImporter 側でも BOM を剥がしてから
        // パースに渡す(BOM 非対称の解消)。
        var bytes = data
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            bytes.removeFirst(3)
        }
        guard let text = String(data: bytes, encoding: .utf8) else {
            Logger.importer.error("CSV is not valid UTF-8")
            throw AppError.importFailed(reason: "csv-not-utf8")
        }
        let rows = CSVParser.parse(text)
        guard let header = rows.first else {
            throw AppError.importFailed(reason: "csv-empty")
        }
        let body = Array(rows.dropFirst())

        let columns = ColumnIndex(header: header)
        guard columns.isValid else {
            Logger.importer.error("CSV header missing required columns: \(header.joined(separator: ","))")
            throw AppError.importFailed(reason: "csv-header-invalid")
        }

        // id → 部分情報 を蓄積していく(ロングフォーマットの再構成)。
        var builders: [String: ExerciseBuilder] = [:]
        var orderedIds: [String] = []
        var malformed = 0

        for (rowIndex, row) in body.enumerated() {
            // セル数が足りない行は欠損列を空文字で補ってリトライ
            let padded = padRow(row, to: header.count)
            guard let id = columns.value(.id, in: padded), !id.isEmpty else {
                malformed += 1
                Logger.importer.error("row \(rowIndex + 2) skipped: missing id")
                continue
            }
            let slug = columns.value(.slug, in: padded) ?? ""
            if slug.isEmpty {
                malformed += 1
                Logger.importer.error("row \(rowIndex + 2) skipped: missing slug for id=\(id)")
                continue
            }

            var builder = builders[id] ?? ExerciseBuilder(legacyCsvId: Int(id), slug: slug)
            if builders[id] == nil {
                orderedIds.append(id)
            }
            // 基本フィールドは行ごとに重複しているはずなので最初の非空値を採用
            builder.merge(
                nameEn: columns.value(.nameEn, in: padded),
                nameJa: columns.value(.nameJa, in: padded),
                descriptionEn: columns.value(.descriptionEn, in: padded),
                descriptionJa: columns.value(.descriptionJa, in: padded),
                introductionEn: columns.value(.introductionEn, in: padded),
                introductionJa: columns.value(.introductionJa, in: padded)
            )

            let attrName = columns.value(.attributeName, in: padded) ?? ""
            let attrValue = columns.value(.attributeValue, in: padded) ?? ""
            if !attrName.isEmpty && !attrValue.isEmpty {
                if !builder.applyAttribute(name: attrName, value: attrValue) {
                    malformed += 1
                    Logger.importer.error("row \(rowIndex + 2) attribute ignored: \(attrName)=\(attrValue)")
                }
            }
            builders[id] = builder
        }

        let parsed: [ParsedExercise] = orderedIds.compactMap { id in
            guard let built = builders[id]?.build() else {
                Logger.importer.error("exercise id=\(id) skipped: incomplete required fields")
                return nil
            }
            return built
        }
        Logger.importer.info("CSV parsed: \(parsed.count) exercises, \(malformed) malformed rows")
        return parsed
    }

    /// パース結果を SwiftData に反映する。slug 衝突時は既存レコードを更新する(冪等)。
    @MainActor
    static func importExercises(
        from data: Data,
        into context: ModelContext
    ) throws -> ImportResult {
        let parsed = try parseExercises(from: data)
        var inserted = 0
        var updated = 0
        var skipped = 0

        for record in parsed {
            let slug = record.slug
            let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.slug == slug })
            let existing = try context.fetch(descriptor)
            if let entity = existing.first {
                if entity.isUserCreated {
                    // ユーザー作成種目は CSV 取り込みで上書きしない(Pro 機能 customExercise 保護)
                    skipped += 1
                    continue
                }
                record.apply(to: entity)
                updated += 1
            } else {
                context.insert(record.makeEntity())
                inserted += 1
            }
        }

        if context.hasChanges {
            try context.save()
        }
        Logger.importer.info("CSV imported: inserted=\(inserted) updated=\(updated) skipped=\(skipped)")
        return ImportResult(inserted: inserted, updated: updated, skipped: skipped, malformedRows: 0)
    }

    // MARK: - Helpers

    private static func padRow(_ row: [String], to count: Int) -> [String] {
        if row.count >= count { return row }
        return row + Array(repeating: "", count: count - row.count)
    }
}
