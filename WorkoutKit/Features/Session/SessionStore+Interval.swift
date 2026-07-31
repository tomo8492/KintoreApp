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
            // B8: 上の await の間に(このタスク自身が)supersede されてキャンセル
            // された場合、そのまま続けると一瞬だけ古いカウントダウンが復活して
            // 見える(前の intervalTask を止めるために先に呼ばれた新しい
            // startIntervalCountdown が、その後さらに別の呼び出しでキャンセルされた
            // ケースなど)。self の生存確認と同じ guard でまとめて弾く。
            guard let self, !Task.isCancelled else { return }
            self.isIntervalRunning = true
            self.intervalSecondsRemaining = seconds
            // B7: 壁時計の終了時刻を保存する。Live Activity 側の intervalEndsAt も
            // この値をそのまま使う(liveActivityState() 参照、二重計算をやめて統一)。
            self.intervalEndsAt = Date().addingTimeInterval(TimeInterval(seconds))
            self.updateLiveActivity()
            let stream = self.intervalTimer.start(seconds: seconds)
            for await value in stream {
                if Task.isCancelled { break }
                self.intervalSecondsRemaining = value
            }
            self.isIntervalRunning = false
            self.intervalSecondsRemaining = nil
            self.intervalEndsAt = nil
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
        intervalEndsAt = nil
        if wasRunning {
            updateLiveActivity()
        }
    }

    // MARK: - B7: フォアグラウンド復帰時の残り秒数補正

    /// SessionLifecycleModifier が scenePhase == .active への遷移で呼ぶ。
    /// IntervalTimer はティックベースでサスペンド中の経過時間を失うため、
    /// 壁時計の `intervalEndsAt` から残り秒数を計算し直し、カウントダウンを補正する。
    /// - 休憩中でなければ何もしない。
    /// - 残り秒数が 0 以下(=サスペンド中に休憩が終わっていた)なら、
    ///   `stopIntervalCountdown()` で自然終了と同じ状態遷移(isIntervalRunning /
    ///   intervalSecondsRemaining / intervalEndsAt のクリアと Live Activity 更新)にする。
    /// - IntervalTimer 自体には残り秒数だけを差し替える API が無いため、休憩が
    ///   まだ続いている場合は `startIntervalCountdown(seconds:)` を呼び直し、
    ///   「停止して補正後の残り秒数で再起動」する。
    func reconcileIntervalCountdown(now: Date = .now) {
        guard isIntervalRunning, let endsAt = intervalEndsAt else { return }

        let remaining = Int(endsAt.timeIntervalSince(now).rounded())
        if remaining <= 0 {
            stopIntervalCountdown()
        } else {
            startIntervalCountdown(seconds: remaining)
        }
    }
}
