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
    /// - 同時に走るタイマーは1つだけ。再起動時は前のタスクを cancel + await し、
    ///   `for await` ループが完全に抜けてから新規 stream を起動する。
    ///   `cancel()` だけだと前タスクが for-await から抜ける前に新タスクが値を
    ///   書き始め、二重サブスクリプションのウィンドウが残る(残秒数が交互に
    ///   上書きされてチカチカする)。
    /// - 起動 1 回につき Live Activity を update する(ContentState.intervalEndsAt
    ///   は Date 1点なので、Widget 側で `Text(timerInterval:)` がローカル描画する。
    ///   毎秒 update を打つ必要はない)。
    func startIntervalCountdown(seconds: Int) {
        // 前タスクをキャプチャしてキャンセルし、完了を待ってから新 stream を起動する。
        // 旧 task の `for await value in stream` は AsyncStream 仕様上、Task が cancel
        // されただけでは自動で抜けない(continuation.finish() が必要)。よって
        // intervalTimer.stop() を呼んで内部 task を止め、stream を確実に finish させる。
        // その後 `await previous.value` で旧 task の終端処理(isIntervalRunning=false など)
        // が完全に終わるまで待ち、二重サブスクリプションのウィンドウを閉じる。
        let previous = intervalTask
        let task: Task<Void, Never> = Task { @MainActor [weak self] in
            if let previous {
                previous.cancel()
                self?.intervalTimer.stop()
                _ = await previous.value
            }
            guard let self else { return }
            self.isIntervalRunning = true
            self.intervalSecondsRemaining = seconds
            self.updateLiveActivity()
            let stream = self.intervalTimer.start(seconds: seconds)
            for await value in stream {
                if Task.isCancelled { break }
                self.intervalSecondsRemaining = value
            }
            self.isIntervalRunning = false
            self.intervalSecondsRemaining = nil
            // 休憩終了時に Live Activity の intervalEndsAt を nil に更新する。
            self.updateLiveActivity()
        }
        intervalTask = task
    }

    /// IntervalTimer とコンシューマタスクを止め、UI 状態をリセットする。
    /// 手動キャンセル時も Live Activity から休憩表示を消す。
    func stopIntervalCountdown() {
        intervalTimer.stop()
        intervalTask?.cancel()
        intervalTask = nil
        let wasRunning = isIntervalRunning
        isIntervalRunning = false
        intervalSecondsRemaining = nil
        if wasRunning {
            updateLiveActivity()
        }
    }
}
