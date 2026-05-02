// MARK: - IntervalTimer
// CLAUDE.md §1.1 F-03 / §-1.6 / §11.4 準拠。
// セット間休憩のカウントダウンを駆動するタイマー。
// - SessionStore から start(seconds:) で起動し、AsyncStream<Int> 経由で残秒数を流す。
// - 残り3秒で軽い振動、0秒で通知音 + 強い振動を発火する。
// - フォアグラウンド前提。バックグラウンド対応(Live Activity)は C3 で扱う。
// - Singleton(.shared)禁止規約のため、SessionStore が所有する。
// - UIImpactFeedbackGenerator のインスタンス化は §11.4 で明示的に許可されている例外。

import Foundation
import AudioToolbox
import UIKit

/// IntervalTimer の副作用(振動・サウンド)を抽象化するプロトコル。
/// テスト時は無音実装を注入し、UIKit / AVFoundation の実呼び出しを避ける。
@MainActor
protocol IntervalTimerFeedback {
    /// 残り3秒の警告フィードバック(軽い振動)。
    func playWarnFeedback()
    /// 0秒到達時の完了フィードバック(通知音 + 強い振動)。
    func playCompleteFeedback()
}

/// 既定実装。UIKit Haptic + AudioToolbox System Sound を使う。
@MainActor
struct SystemIntervalTimerFeedback: IntervalTimerFeedback {

    /// SystemSoundID 1057 は "Tink"。短く目立つ通知音として F-03 用途に適している。
    /// 通知音 ID は CoreAudio の系統サウンド一覧に固定で割り当てられている既定値。
    private static let completionSoundId: SystemSoundID = 1057

    func playWarnFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    func playCompleteFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        AudioServicesPlaySystemSound(Self.completionSoundId)
    }
}

@MainActor
final class IntervalTimer {

    // MARK: - Tunables

    /// 1tick あたりの待機時間。実機は 1 秒、テストは ms オーダーで差し替える。
    var tickInterval: Duration = .seconds(1)

    // MARK: - Stored state

    private var task: Task<Void, Never>?
    private let feedback: any IntervalTimerFeedback

    // MARK: - Init

    init(feedback: any IntervalTimerFeedback = SystemIntervalTimerFeedback()) {
        self.feedback = feedback
    }

    deinit {
        // MainActor isolated でないが、Task#cancel は nonisolated なので呼べる。
        task?.cancel()
    }

    // MARK: - Public API

    /// `seconds` 秒のカウントダウンを開始し、残秒数を AsyncStream で返す。
    /// 既に走っているタイマーがあれば停止してから再起動する。
    /// - 最初の値として `seconds` を即時 yield し、その後 tickInterval ごとに 1 ずつ減算する。
    /// - 0 を yield した直後にストリームを finish する。
    /// - `seconds <= 0` のときは 0 を1回だけ yield して即 finish する。
    func start(seconds: Int) -> AsyncStream<Int> {
        stop()

        let normalized = max(0, seconds)
        let interval = tickInterval
        let (stream, continuation) = AsyncStream<Int>.makeStream(of: Int.self)

        let newTask = Task { @MainActor [weak self] in
            // 起点を即時 yield(UI が休憩開始時点で最大値を表示できる)。
            var remaining = normalized
            continuation.yield(remaining)
            self?.handleTick(remaining: remaining)

            while remaining > 0 {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    // sleep が cancel されたら静かに抜ける(ストリームは finish させる)。
                    break
                }
                if Task.isCancelled { break }

                remaining -= 1
                continuation.yield(remaining)
                self?.handleTick(remaining: remaining)
            }
            continuation.finish()
        }
        self.task = newTask
        return stream
    }

    /// カウントダウンを即停止する。進行中のストリームは finish される。
    func stop() {
        task?.cancel()
        task = nil
    }

    // MARK: - Internal

    private func handleTick(remaining: Int) {
        switch remaining {
        case 3:
            feedback.playWarnFeedback()
        case 0:
            feedback.playCompleteFeedback()
        default:
            break
        }
    }
}
