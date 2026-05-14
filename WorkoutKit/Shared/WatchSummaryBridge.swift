// MARK: - WatchSummaryBridge
// CLAUDE.md v1.0 §-1.19 / §3-4 準拠。
//
// iPhone App 側で `TodaySessionSummary` を App Group 共有 UserDefaults に書き、
// watchOS Widget 側で読む薄いゲート。
//
// なぜ UserDefaults なのか:
//   - watchOS Widget は短命プロセス。読み込みコストが極小である必要がある。
//   - JSON 1 件だけなので Plist より UserDefaults の Data 値で十分。
//   - SwiftData 共有ストアに比べて Schema 依存が消える(Widget の Bundle 軽量化)。
//   - 書き込み頻度はセッションごと数回(finish / abort 時)なので I/O 負荷無視可能。
//
// 書き込みタイミング:
//   - WorkoutSession.finish() / abort() 直後
//   - 起動時の seed 反映後(初日からウィジェットに「今日 0 セット」を出すため)
//
// 読み込み:
//   - WorkoutWidgetProvider.getTimeline / getSnapshot で本ファイルの read() を呼ぶ。

import Foundation
import OSLog

private let watchBridgeLogger = Logger(subsystem: "com.tomo.workoutkit", category: "watch-bridge")

public enum WatchSummaryBridge {

    /// 共有 UserDefaults スイート名。CLAUDE.md v1.0 §3-4 確定値。
    public static let appGroupID = "group.com.tomo.workoutkit"

    /// `TodaySessionSummary` を JSON エンコードして格納するキー。
    public static let summaryKey = "watch.today.summary"

    /// 共有 UserDefaults を返す。App Group が entitlement で許可されていない場合は
    /// .standard にフォールバックする(本来は entitlement で許可必須)。
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // MARK: - Write (App side)

    /// `TodaySessionSummary` を共有 UserDefaults に書き込む。
    /// 失敗時はログを残して握りつぶす(Widget が古い値を表示するだけで問題は連鎖しない)。
    public static func write(_ summary: TodaySessionSummary) {
        do {
            let data = try JSONEncoder().encode(summary)
            defaults.set(data, forKey: summaryKey)
        } catch {
            watchBridgeLogger.error("WatchSummaryBridge.write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Read (Widget side)

    /// 共有 UserDefaults から読み出す。値が無い / decode 失敗時は `.empty` を返す。
    /// `Calendar.isDateInToday(_:)` で日付チェックして「昨日以前の値」なら empty にダウングレード。
    public static func read(now: Date = .now, calendar: Calendar = .current) -> TodaySessionSummary {
        guard let data = defaults.data(forKey: summaryKey),
              let summary = try? JSONDecoder().decode(TodaySessionSummary.self, from: data)
        else {
            return .empty
        }
        // 日付チェック: updatedAt が今日でなければ表示用は .empty 相当に
        // (Widget は今日の状況だけを反映する設計、§5-4)。
        if calendar.isDate(summary.updatedAt, inSameDayAs: now) {
            return summary
        }
        return TodaySessionSummary(
            updatedAt: now,
            isCompletedToday: false,
            totalSetsToday: 0,
            exerciseCountToday: 0
        )
    }
}
