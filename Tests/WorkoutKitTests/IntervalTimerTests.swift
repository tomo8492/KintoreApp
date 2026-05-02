// MARK: - IntervalTimerTests
// CLAUDE.md §1.1 F-03 / §9.1 / §11.4 準拠。
// Swift Testing で IntervalTimer の主要パスを凍結する。
// - 実時間ではなく tickInterval を 5ms に縮めることで、5秒カウントダウンも数十msで完了する。
// - 振動・サウンドは MuteFeedback で観測のみ行い、実際には UIKit / AVFoundation を呼ばない。

import Foundation
import Testing
@testable import WorkoutKit

@MainActor
@Suite("IntervalTimer")
struct IntervalTimerTests {

    /// 警告/完了の発火回数だけ記録するテスト用フィードバック。
    @MainActor
    final class MuteFeedback: IntervalTimerFeedback {
        private(set) var warnCalls = 0
        private(set) var completeCalls = 0
        func playWarnFeedback() { warnCalls += 1 }
        func playCompleteFeedback() { completeCalls += 1 }
    }

    /// テスト用の高速 IntervalTimer を組む(tick=5ms、副作用は MuteFeedback)。
    private static func makeTimer() -> (IntervalTimer, MuteFeedback) {
        let feedback = MuteFeedback()
        let timer = IntervalTimer(feedback: feedback)
        timer.tickInterval = .milliseconds(5)
        return (timer, feedback)
    }

    /// AsyncStream を全部吸い出してリストにする。
    private static func collect(_ stream: AsyncStream<Int>) async -> [Int] {
        var out: [Int] = []
        for await v in stream { out.append(v) }
        return out
    }

    @Test("5秒カウントダウンは 5,4,3,2,1,0 の順に yield される")
    func countdownYieldsDescendingSequence() async {
        let (timer, _) = Self.makeTimer()
        let stream = timer.start(seconds: 5)
        let yielded = await Self.collect(stream)
        #expect(yielded == [5, 4, 3, 2, 1, 0])
    }

    @Test("0秒で start すると 0 を1回だけ yield して finish する")
    func zeroSecondsYieldsZeroOnce() async {
        let (timer, _) = Self.makeTimer()
        let stream = timer.start(seconds: 0)
        let yielded = await Self.collect(stream)
        #expect(yielded == [0])
    }

    @Test("負数が渡されたら 0 として扱う(防御的クランプ)")
    func negativeSecondsClampedToZero() async {
        let (timer, _) = Self.makeTimer()
        let stream = timer.start(seconds: -5)
        let yielded = await Self.collect(stream)
        #expect(yielded == [0])
    }

    @Test("残り3秒で警告フィードバック、0秒で完了フィードバックがそれぞれ1回ずつ発火する")
    func feedbackFiresAtThreeAndZero() async {
        let (timer, feedback) = Self.makeTimer()
        let stream = timer.start(seconds: 5)
        _ = await Self.collect(stream)
        #expect(feedback.warnCalls == 1)
        #expect(feedback.completeCalls == 1)
    }

    @Test("3秒未満から開始した場合は警告フィードバックは出ず、完了フィードバックだけ出る")
    func warnNotFiredWhenStartingBelowThree() async {
        let (timer, feedback) = Self.makeTimer()
        let stream = timer.start(seconds: 2)
        let yielded = await Self.collect(stream)
        #expect(yielded == [2, 1, 0])
        #expect(feedback.warnCalls == 0)
        #expect(feedback.completeCalls == 1)
    }

    @Test("stop() でストリームが finish し、それ以降の値は流れない")
    func stopFinishesStreamAndHaltsTicks() async {
        let (timer, _) = Self.makeTimer()
        // 60秒分のカウントダウン(実時間でも 60×5ms = 300ms 以内に終わる想定だが、
        // 直後に stop して途中で止まることを検証する)。
        let stream = timer.start(seconds: 60)

        var collected: [Int] = []
        var iterator = stream.makeAsyncIterator()
        // 最初の値(=60)を必ず受け取る。
        if let first = await iterator.next() {
            collected.append(first)
        }
        timer.stop()

        // stop 後は次の値が来ても来なくてもよいが、ストリームは有限時間内に finish すること。
        // 残りの値を読み切って終端を確認する。
        while let v = await iterator.next() {
            collected.append(v)
        }

        // 最初の値は 60 で固定。
        #expect(collected.first == 60)
        // 60 個全部は yield されない(stop で打ち切られる)。
        #expect(collected.count < 61)
    }

    @Test("既に走っているタイマーに対して再度 start すると、前のストリームは finish する")
    func startCancelsPreviousStream() async {
        let (timer, _) = Self.makeTimer()
        let firstStream = timer.start(seconds: 30)

        // 最初の値だけ取って、再度 start する。
        var firstIter = firstStream.makeAsyncIterator()
        let first = await firstIter.next()
        #expect(first == 30)

        let secondStream = timer.start(seconds: 3)

        // 第1ストリームは finish するはず(残りを読み切る)。
        var firstTail: [Int] = []
        while let v = await firstIter.next() {
            firstTail.append(v)
        }
        // 第1ストリームは 30 個全部は流れない。
        #expect(firstTail.count < 30)

        // 第2ストリームは正常に 3,2,1,0 を流す。
        let secondYielded = await Self.collect(secondStream)
        #expect(secondYielded == [3, 2, 1, 0])
    }
}
