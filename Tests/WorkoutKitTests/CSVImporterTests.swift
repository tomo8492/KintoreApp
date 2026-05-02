// MARK: - CSVImporterTests
// CLAUDE.md §9.1 / §1.1 F-06 準拠。Swift Testing で workout-cool 互換 CSV のラウンドトリップを検証。
// テスト用 CSV は Tests/WorkoutKitTests/Resources/sample-exercises.csv に配置。

import Foundation
import Testing
@testable import WorkoutKit

@Suite("CSVImporter")
struct CSVImporterTests {

    // MARK: - Sample loader

    private static func loadSample() throws -> Data {
        // Bundle.module は SwiftPM テストターゲットでのみ動く。Xcode の場合は file パスから読む。
        if let url = Bundle.module.url(forResource: "sample-exercises", withExtension: "csv") {
            return try Data(contentsOf: url)
        }
        // フォールバック: ファイルパスから直接読む(Xcode 直接実行 / SPM 未設定時)。
        let here = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/sample-exercises.csv")
        return try Data(contentsOf: here)
    }

    // MARK: - Tests

    @Test("workout-cool ロングフォーマットを id でグループ化して種目に再構成する")
    func parsesLongFormatGroupedById() throws {
        let data = try Self.loadSample()
        let parsed = try CSVImporter.parseExercises(from: data)

        // 必須属性が揃っている: barbell-back-squat / push-up / cat-cow / bad-attr
        // 欠ける: broken-row(slug 無し) / no-attrs(必須属性無し)
        let slugs = parsed.map(\.slug)
        #expect(slugs.contains("barbell-back-squat"))
        #expect(slugs.contains("push-up"))
        #expect(slugs.contains("cat-cow"))
        #expect(slugs.contains("bad-attr"))
        #expect(!slugs.contains("broken-row"))
        #expect(!slugs.contains("no-attrs"))
    }

    @Test("各属性が enum rawValue へ正規化される(SNAKE_CASE → lowerCamelCase)")
    func normalizesAttributeValues() throws {
        let data = try Self.loadSample()
        let parsed = try CSVImporter.parseExercises(from: data)

        let squat = try #require(parsed.first { $0.slug == "barbell-back-squat" })
        #expect(squat.typeRaw == ExerciseType.strength.rawValue)
        #expect(squat.mechanicsTypeRaw == MechanicsType.compound.rawValue)
        #expect(squat.primaryMuscleRaw == Muscle.quadriceps.rawValue)
        #expect(squat.secondaryMusclesRaw.split(separator: ",").map(String.init).sorted()
                == [Muscle.glutes.rawValue, Muscle.hamstrings.rawValue].sorted())
        #expect(squat.equipmentRaw == Equipment.barbell.rawValue)
        #expect(squat.legacyCsvId == 1)

        let pushup = try #require(parsed.first { $0.slug == "push-up" })
        #expect(pushup.typeRaw == ExerciseType.calisthenics.rawValue)
        #expect(pushup.primaryMuscleRaw == Muscle.chest.rawValue)
        // BODY_ONLY は bodyweight に正規化される
        #expect(pushup.equipmentRaw == Equipment.bodyweight.rawValue)
    }

    @Test("WARMUP / YOGA_MAT / LOWER_BACK の正規化が走る")
    func normalizesWarmupRow() throws {
        let data = try Self.loadSample()
        let parsed = try CSVImporter.parseExercises(from: data)

        let stretch = try #require(parsed.first { $0.slug == "cat-cow" })
        #expect(stretch.typeRaw == ExerciseType.warmup.rawValue)
        #expect(stretch.primaryMuscleRaw == Muscle.lowerBack.rawValue)
        #expect(stretch.equipmentRaw == Equipment.yogaMat.rawValue)
    }

    @Test("不明な属性名 (WHATEVER) があってもクラッシュせず他属性は採用される")
    func ignoresUnknownAttributes() throws {
        let data = try Self.loadSample()
        let parsed = try CSVImporter.parseExercises(from: data)

        let bad = try #require(parsed.first { $0.slug == "bad-attr" })
        #expect(bad.typeRaw == ExerciseType.strength.rawValue)
        #expect(bad.primaryMuscleRaw == Muscle.chest.rawValue)
    }

    @Test("空文字列 / 不正な行が混じってもクラッシュしない")
    func malformedRowsDontCrash() throws {
        // ヘッダはあるが本文が空
        let onlyHeader = Data("id,slug,attribute_name,attribute_value\n".utf8)
        let parsed = try CSVImporter.parseExercises(from: onlyHeader)
        #expect(parsed.isEmpty)

        // 列が極端に少ない行
        let short = Data("""
        id,slug,attribute_name,attribute_value
        7
        ,,,
        """.utf8)
        let parsed2 = try CSVImporter.parseExercises(from: short)
        #expect(parsed2.isEmpty)
    }

    @Test("ヘッダが致命的に欠損していたら importFailed を投げる")
    func throwsOnInvalidHeader() {
        let bogus = Data("foo,bar\nx,y\n".utf8)
        do {
            _ = try CSVImporter.parseExercises(from: bogus)
            Issue.record("expected importFailed but got success")
        } catch let error as AppError {
            switch error {
            case .importFailed: break
            default: Issue.record("expected importFailed but got \(error)")
            }
        } catch {
            Issue.record("expected AppError but got \(error)")
        }
    }

    @Test("UTF-8 ではないデータは importFailed として弾く")
    func rejectsNonUtf8() {
        // UTF-16 BOM 付きデータは UTF-8 デコード失敗を狙う
        let bytes: [UInt8] = [0xFF, 0xFE, 0x42, 0x00, 0x43, 0x00]
        let data = Data(bytes)
        do {
            _ = try CSVImporter.parseExercises(from: data)
            Issue.record("expected importFailed but got success")
        } catch let error as AppError {
            switch error {
            case .importFailed: break
            default: Issue.record("expected importFailed but got \(error)")
            }
        } catch {
            Issue.record("expected AppError but got \(error)")
        }
    }
}

// MARK: - CSVParserTests
// 区切り文字 / クォート / エスケープの基本仕様を凍結する。

@Suite("CSVParser")
struct CSVParserTests {

    @Test("シンプルなカンマ区切りをパースできる")
    func basic() {
        let rows = CSVParser.parse("a,b,c\n1,2,3\n4,5,6")
        #expect(rows == [["a","b","c"],["1","2","3"],["4","5","6"]])
    }

    @Test("引用符内のカンマと改行を保持する")
    func quotedFields() {
        let csv = "name,desc\n\"Squat\",\"line1\nline2, with comma\""
        let rows = CSVParser.parse(csv)
        #expect(rows.count == 2)
        #expect(rows[1] == ["Squat", "line1\nline2, with comma"])
    }

    @Test("ダブルクォートのエスケープ ( \"\" → \" )")
    func escapedQuote() {
        let csv = "a,b\n\"he said \"\"hi\"\"\",ok"
        let rows = CSVParser.parse(csv)
        #expect(rows[1] == ["he said \"hi\"", "ok"])
    }

    @Test("CRLF 改行も LF と同じく扱う")
    func crlfHandling() {
        let csv = "a,b\r\n1,2\r\n3,4\r\n"
        let rows = CSVParser.parse(csv)
        #expect(rows == [["a","b"],["1","2"],["3","4"]])
    }

    @Test("escape() は必要なときだけ引用符で囲む")
    func escape() {
        #expect(CSVParser.escape("simple") == "simple")
        #expect(CSVParser.escape("with,comma") == "\"with,comma\"")
        #expect(CSVParser.escape("with\"quote") == "\"with\"\"quote\"")
        #expect(CSVParser.escape("with\nnewline") == "\"with\nnewline\"")
    }
}
