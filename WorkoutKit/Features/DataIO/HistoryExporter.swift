// MARK: - HistoryExporter
// CLAUDE.md §1.1 F-06 / §-1.4 準拠。
// WorkoutSession 履歴を CSV にエクスポートする。
// 単位は内部単位ロックに従い、重量は kg のまま、時刻は ISO 8601(UTC)で書き出す。
// 表示用ロケール変換はしない(後で再インポートすると壊れるため)。

import Foundation

enum HistoryExporter {

    /// CSV のカラム順序。Importer 側のラウンドトリップ前提でこの順を変えない。
    static let columns: [String] = [
        "session_id",
        "started_at",
        "finished_at",
        "time_zone",
        "goal",
        "includes_warmup",
        "includes_cooldown",
        "is_manual_entry",
        "notes",
        "set_id",
        "set_order",
        "section",
        "exercise_slug",
        "reps",
        "weight_kg",
        "rpe",
        "rest_seconds",
        "duration_seconds",
        "completed_at"
    ]

    /// セッション配列を 1 行 = 1 セット の CSV にエクスポートする。
    /// セットを持たないセッションも 1 行残す(列はセット項目のみ空)。
    /// - Returns: BOM を付けた UTF-8 データ。Excel 互換のため。
    static func exportCSV(_ sessions: [WorkoutSession]) -> Data {
        var lines: [String] = []
        lines.append(CSVParser.writeRow(columns))

        for session in sessions {
            let setsSorted = session.sets.sorted { $0.order < $1.order }
            if setsSorted.isEmpty {
                lines.append(CSVParser.writeRow(emptyRow(for: session)))
                continue
            }
            for set in setsSorted {
                lines.append(CSVParser.writeRow(row(for: session, set: set)))
            }
        }

        let body = lines.joined(separator: "\n") + "\n"
        var data = Data([0xEF, 0xBB, 0xBF])  // UTF-8 BOM
        data.append(body.data(using: .utf8) ?? Data())
        return data
    }

    // MARK: - Private

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static func iso(_ date: Date?) -> String {
        guard let date else { return "" }
        return isoFormatter.string(from: date)
    }

    private static func emptyRow(for session: WorkoutSession) -> [String] {
        [
            session.id.uuidString,
            iso(session.startedAt),
            iso(session.finishedAt),
            session.timeZoneIdentifier,
            session.goalRaw,
            String(session.includesWarmup),
            String(session.includesCooldown),
            String(session.isManualEntry),
            session.notes,
            "", "", "", "", "", "", "", "", "", ""
        ]
    }

    private static func row(for session: WorkoutSession, set: ExerciseSet) -> [String] {
        [
            session.id.uuidString,
            iso(session.startedAt),
            iso(session.finishedAt),
            session.timeZoneIdentifier,
            session.goalRaw,
            String(session.includesWarmup),
            String(session.includesCooldown),
            String(session.isManualEntry),
            session.notes,
            set.id.uuidString,
            String(set.order),
            set.sectionRaw,
            set.exercise?.slug ?? "",
            String(set.reps),
            String(set.weightKg),
            set.rpe.map { String($0) } ?? "",
            String(set.restSeconds),
            set.durationSeconds.map { String($0) } ?? "",
            iso(set.completedAt)
        ]
    }
}

// MARK: - HistoryExporter+Parse
// テストとラウンドトリップ用に CSV を読んで構造化レコードを返す。
// SwiftData には書き戻さず、検証用の中間型に詰める。

extension HistoryExporter {

    struct ParsedSession: Sendable, Equatable {
        var sessionId: UUID
        var startedAt: Date?
        var finishedAt: Date?
        var timeZoneIdentifier: String
        var goalRaw: String
        var includesWarmup: Bool
        var includesCooldown: Bool
        var isManualEntry: Bool
        var notes: String
        var sets: [ParsedSet]
    }

    struct ParsedSet: Sendable, Equatable {
        var setId: UUID
        var order: Int
        var sectionRaw: String
        var exerciseSlug: String
        var reps: Int
        var weightKg: Double
        var rpe: Double?
        var restSeconds: Int
        var durationSeconds: Int?
        var completedAt: Date?
    }

    static func parseCSV(_ data: Data) -> [ParsedSession] {
        var bytes = data
        // BOM を剥がす
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            bytes.removeFirst(3)
        }
        guard let text = String(data: bytes, encoding: .utf8) else { return [] }
        let rows = CSVParser.parse(text)
        guard rows.count >= 2 else { return [] }
        let header = rows[0]
        let body = Array(rows.dropFirst())

        var indexOf: [String: Int] = [:]
        for (i, name) in header.enumerated() {
            indexOf[name.trimmingCharacters(in: .whitespacesAndNewlines)] = i
        }
        func cell(_ row: [String], _ col: String) -> String {
            guard let i = indexOf[col], i < row.count else { return "" }
            return row[i]
        }

        var byId: [UUID: ParsedSession] = [:]
        var orderedIds: [UUID] = []

        for row in body {
            guard let sessionId = UUID(uuidString: cell(row, "session_id")) else { continue }
            if byId[sessionId] == nil {
                let session = ParsedSession(
                    sessionId: sessionId,
                    startedAt: isoFormatter.date(from: cell(row, "started_at")),
                    finishedAt: isoFormatter.date(from: cell(row, "finished_at")),
                    timeZoneIdentifier: cell(row, "time_zone"),
                    goalRaw: cell(row, "goal"),
                    includesWarmup: Bool(cell(row, "includes_warmup")) ?? true,
                    includesCooldown: Bool(cell(row, "includes_cooldown")) ?? true,
                    isManualEntry: Bool(cell(row, "is_manual_entry")) ?? false,
                    notes: cell(row, "notes"),
                    sets: []
                )
                byId[sessionId] = session
                orderedIds.append(sessionId)
            }

            // セット部が空ならスキップ(セッションのみ)
            let setIdStr = cell(row, "set_id")
            guard !setIdStr.isEmpty, let setId = UUID(uuidString: setIdStr) else { continue }
            let set = ParsedSet(
                setId: setId,
                order: Int(cell(row, "set_order")) ?? 0,
                sectionRaw: cell(row, "section").isEmpty
                    ? SessionSection.main.rawValue
                    : cell(row, "section"),
                exerciseSlug: cell(row, "exercise_slug"),
                reps: Int(cell(row, "reps")) ?? 0,
                weightKg: Double(cell(row, "weight_kg")) ?? 0,
                rpe: Double(cell(row, "rpe")),
                restSeconds: Int(cell(row, "rest_seconds")) ?? 0,
                durationSeconds: Int(cell(row, "duration_seconds")),
                completedAt: isoFormatter.date(from: cell(row, "completed_at"))
            )
            byId[sessionId]?.sets.append(set)
        }

        return orderedIds.compactMap { byId[$0] }
    }
}
