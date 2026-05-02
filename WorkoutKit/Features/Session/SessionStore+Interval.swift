// MARK: - SessionStore + Interval
// CLAUDE.md §1.1 F-03 / §-1.6 / §11 準拠。
// IntervalTimer を SessionStore の観測プロパティに接続するヘルパー。
// 単一ファイル 300 行制約のため、本機能だけ別ファイルに切り出している。
// SessionStore の intervalTimer / intervalTask / intervalSecondsRemaining /
// isIntervalRunning は本拡張からのみ書き込みを行う(同モジュール内、他からは触らない)。

import Foundation

extension SessionStore {

    /// 休憩スキップなど、View 側からインターバルを手動で止めるための公開 API。
    func cancelInterval() {
        stopIntervalCountdown()
    }

    /// IntervalTimer を起動し、AsyncStream の出力を観測プロパティに反映する。
    /// - 同時に走るタイマーは1つだけ。再起動時は前のタスクをキャンセルする。
    func startIntervalCountdown(seconds: Int) {
        intervalTask?.cancel()
        isIntervalRunning = true
        intervalSecondsRemaining = seconds
        let stream = intervalTimer.start(seconds: seconds)
        intervalTask = Task { @MainActor [weak self] in
            for await value in stream {
                self?.intervalSecondsRemaining = value
            }
            self?.isIntervalRunning = false
            self?.intervalSecondsRemaining = nil
        }
    }

    /// IntervalTimer とコンシューマタスクを止め、UI 状態をリセットする。
    func stopIntervalCountdown() {
        intervalTimer.stop()
        intervalTask?.cancel()
        intervalTask = nil
        isIntervalRunning = false
        intervalSecondsRemaining = nil
    }
}
