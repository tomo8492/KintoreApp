// MARK: - CSVParser
// 軽量な RFC 4180 風 CSV パーサ。CSVImporter と HistoryExporter から共有する。
// 改行・引用符付きフィールド・エスケープされた二重引用符 ("") に対応する。
// CSV 仕様の細部に揺れがあっても "クラッシュしない" ことを優先(NGリスト準拠)。

import Foundation

enum CSVParser {

    /// 1ファイル分の CSV を 2 次元配列にパースする。
    /// - Parameters:
    ///   - text: UTF-8 で読み取った CSV 全文。
    ///   - delimiter: フィールド区切り文字(workout-cool は "," 固定)。
    /// - Returns: 行 → セルの配列。空行はスキップする。
    static func parse(_ text: String, delimiter: Character = ",") -> [[String]] {
        var rows: [[String]] = []
        var current: [String] = []
        var field = ""
        var inQuotes = false

        var iterator = text.unicodeScalars.makeIterator()
        var pending: Unicode.Scalar?

        while true {
            let scalar: Unicode.Scalar
            if let p = pending {
                scalar = p
                pending = nil
            } else if let next = iterator.next() {
                scalar = next
            } else {
                break
            }

            let char = Character(scalar)

            if inQuotes {
                if char == "\"" {
                    // ピーク: "" は単一の " として取り込む
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            pending = next
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == delimiter {
                    current.append(field)
                    field = ""
                } else if char == "\n" || char == "\r" {
                    current.append(field)
                    field = ""
                    if !(current.count == 1 && current[0].isEmpty) {
                        rows.append(current)
                    }
                    current = []
                    // CRLF の場合は LF を1つ捨てる
                    if char == "\r", let next = iterator.next() {
                        if next != "\n" {
                            pending = next
                        }
                    }
                } else {
                    field.append(char)
                }
            }
        }

        // 末尾のフィールド / 行を回収
        if !field.isEmpty || !current.isEmpty {
            current.append(field)
            if !(current.count == 1 && current[0].isEmpty) {
                rows.append(current)
            }
        }

        return rows
    }

    /// 1 セル分の値を CSV 仕様で安全にエスケープする。
    /// - 含まれる場合は引用符で囲む: 区切り文字 / " / 改行
    /// - 引用符は "" にエスケープ
    /// - 先頭が `=` `+` `-` `@` `\t` `\r` の場合は Excel / Numbers / Google Sheets の
    ///   formula injection (CWE-1236 / OWASP CSV Injection) を防ぐためシングルクォートを
    ///   先頭に挿入する。ユーザー入力の exercise name や note を後でスプレッドシートで
    ///   開く可能性があるため、エクスポート時点で無害化しておく。
    static func escape(_ value: String, delimiter: Character = ",") -> String {
        let sanitized = sanitizeFormulaPrefix(value)
        let needsQuoting = sanitized.contains(delimiter)
            || sanitized.contains("\"")
            || sanitized.contains("\n")
            || sanitized.contains("\r")
        if !needsQuoting { return sanitized }
        let escaped = sanitized.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    /// CSV Injection 対策。先頭文字が数式トリガなら `'` を 1 文字だけ前置する。
    /// Excel / Numbers / Google Sheets はこの prefix を表示時に剥がしてくれる
    /// (= 元の文字列として可読、かつ数式評価はされない)。
    private static func sanitizeFormulaPrefix(_ value: String) -> String {
        guard let first = value.first else { return value }
        let triggers: Set<Character> = ["=", "+", "-", "@", "\t", "\r"]
        if triggers.contains(first) {
            return "'" + value
        }
        return value
    }

    /// 行 → CSV 文字列(改行は LF)。
    static func writeRow(_ cells: [String], delimiter: Character = ",") -> String {
        cells.map { escape($0, delimiter: delimiter) }.joined(separator: String(delimiter))
    }
}
