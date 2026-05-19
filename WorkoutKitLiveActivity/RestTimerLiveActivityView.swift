// MARK: - RestTimerLiveActivity
// CLAUDE.md v0.5 §-1.18 準拠。
//
// レストタイマー用 ActivityConfiguration。
// 既存 SessionLiveActivity(セッション全体)と同一 Widget Bundle に追加で登録する。
// WidgetBundleBuilder は最大 5 Widget まで許容するので併存 OK。
//
// 描画戦略:
//   - 残時間は state.endTime を Text(timerInterval:countsDown:) に渡し、
//     端末側で 1Hz ローカル描画する(activity.update を毎秒打たない)。
//   - endTime <= now になったら表示が "00:00" で止まる(visual の終端)。
//     ActivityKit 側の自動 dismiss は staleDate 30 秒で起動するが、
//     基本は App 側 RestTimerManager.stop() で能動的に終了させる。

import ActivityKit
import SwiftUI
import WidgetKit

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            RestTimerLockScreenView(state: context.state, attributes: context.attributes)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            // WWDC23 "Design dynamic Live Activities" 準拠の Dynamic Island レイアウト:
            //   - 各エリアは Dynamic Island の丸い形状と concentric に配置
            //   - compact / minimal は情報密度を最大化(空白を残さない)
            //   - expanded は app の personality を出しつつタイマーを最も目立たせる
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    // 円形バックに timer アイコンを入れることで Dynamic Island
                    // の rounded 形状と concentric に揃える(WWDC23 ガイドライン)。
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 38, height: 38)
                        Image(systemName: "timer")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                    .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: .now ... context.state.endTime, countsDown: true)
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .frame(maxWidth: 92)
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.exerciseName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    setProgressLine(state: context.state)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } compactLeading: {
                // compact 状態は左右にぴったり寄せる(WWDC23: snug against the sensor)。
                Image(systemName: "timer")
                    .foregroundStyle(.tint)
                    .accessibilityLabel(Text("rest.live.title"))
            } compactTrailing: {
                Text(timerInterval: .now ... context.state.endTime, countsDown: true)
                    .monospacedDigit()
                    .foregroundStyle(.tint)
                    .frame(maxWidth: 56)
            } minimal: {
                // minimal は情報を捨てずカウントダウン残時間を表示。
                // 複数 Live Activity が並走したときも識別できるよう色は tint で着色。
                Text(timerInterval: .now ... context.state.endTime, countsDown: true)
                    .monospacedDigit()
                    .foregroundStyle(.tint)
            }
            .keylineTint(.accentColor)
        }
    }

    @ViewBuilder
    private func setProgressLine(state: RestTimerState) -> some View {
        if state.totalSetsForExercise > 0 {
            // LocalizedStringKey の string-interpolation で %lld を埋める。
            // Catalog 側の値は「次は %lld / %lld セット」「Next: set %lld of %lld」
            // のように位置パラメータで定義する(rest.live.next-set %lld %lld)。
            Text("rest.live.next-set \(state.nextSetNumber) \(state.totalSetsForExercise)")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("rest.live.next-set.no-count")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - LockScreenView

private struct RestTimerLockScreenView: View {
    let state: RestTimerState
    let attributes: RestTimerAttributes

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(.tint)
                Text("rest.live.title")
                    .font(.headline)
                Spacer()
                Text(timerInterval: .now ... state.endTime, countsDown: true)
                    .font(.title.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            Text(state.exerciseName)
                .font(.title3.bold())
                .lineLimit(1)
                .truncationMode(.tail)
            if state.totalSetsForExercise > 0 {
                Text("rest.live.next-set \(state.nextSetNumber) \(state.totalSetsForExercise)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("rest.live.next-set.no-count")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        // WWDC23 "Design dynamic Live Activities" のガイドライン:
        // ロック画面 Live Activity は 14pt 余白で統一すると、複数 Activity
        // 並列表示時にもグリッド見えが整う。デフォルト `.padding()` は 16pt。
        .padding(14)
    }
}

// MARK: - Preview

#if DEBUG
extension RestTimerAttributes {
    fileprivate static var preview: RestTimerAttributes {
        RestTimerAttributes(
            workoutName: "ベンチプレス Day",
            sessionId: UUID()
        )
    }
}

extension RestTimerState {
    fileprivate static var counting: Self {
        .init(
            endTime: Date().addingTimeInterval(45),
            exerciseName: "バーベルベンチプレス",
            nextSetNumber: 3,
            totalSetsForExercise: 5
        )
    }
}

#Preview("LockScreen / counting", as: .content, using: RestTimerAttributes.preview) {
    RestTimerLiveActivity()
} contentStates: {
    RestTimerState.counting
}
#endif
