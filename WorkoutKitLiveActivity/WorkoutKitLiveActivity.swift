// MARK: - WorkoutKitLiveActivity (Widget Extension)
// CLAUDE.md §1.1 F-03 / §-1.5 / §11.4 準拠。
//
// ActivityKit + WidgetKit による Live Activity。
// - ロック画面: セッション進捗 + 現在種目 + 休憩タイマー
// - Dynamic Island: expanded(同上)/ compact(残秒数)/ minimal(アイコンのみ)
//
// 表示文字列は全て String Catalog 経由(NGリスト規約)。Widget Extension は
// アプリ本体とは別 Bundle なので、`Localizable.xcstrings` をビルド時にコピーする
// 設定が project.yml の `bundleResources` 経由で必要。共通化はビルド設定で行う。

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct WorkoutKitLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        SessionLiveActivity()
        // v0.5 §-1.18: レストタイマー専用 Live Activity を併存させる。
        // 同一 Widget Bundle 内に複数 ActivityConfiguration を持てる(最大 5 まで)。
        RestTimerLiveActivity()
    }
}

// MARK: - Live Activity 本体

struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionLiveActivityAttributes.self) { context in
            // ロック画面・通知バナー
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展開時(ロングプレス時)
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(verbatim: "\(context.state.progress)/\(context.state.total)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.currentExerciseDisplayName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    intervalLine(state: context.state, font: .title2)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                if let endsAt = context.state.intervalEndsAt, endsAt > .now {
                    Text(timerInterval: .now...endsAt, countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 56)
                } else {
                    Text(verbatim: "\(context.state.progress)/\(context.state.total)")
                        .monospacedDigit()
                }
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.tint)
            }
            .keylineTint(.accentColor)
        }
    }

    /// 休憩タイマー / 完了状態の共通ライン。expanded.bottom と LockScreen で使い回す。
    @ViewBuilder
    private func intervalLine(state: SessionLiveActivityState, font: Font) -> some View {
        if let endsAt = state.intervalEndsAt, endsAt > .now {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .foregroundStyle(.secondary)
                Text(timerInterval: .now...endsAt, countsDown: true)
                    .font(font.monospacedDigit())
            }
        } else {
            Text("session.live.ready")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - LockScreenView
// 通知センター・ロック画面に表示される本体。Dynamic Island の expanded と
// 同じ情報密度で揃える(ユーザーが切替時に違和感ないように)。

private struct LockScreenView: View {
    let state: SessionLiveActivityState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.tint)
                Text("session.live.title")
                    .font(.headline)
                Spacer()
                Text(verbatim: "\(state.progress)/\(state.total)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(state.currentExerciseDisplayName)
                .font(.title3.bold())
                .lineLimit(1)
                .truncationMode(.tail)
            intervalRow
        }
        .padding()
    }

    @ViewBuilder
    private var intervalRow: some View {
        if let endsAt = state.intervalEndsAt, endsAt > .now {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .foregroundStyle(.secondary)
                Text(timerInterval: .now...endsAt, countsDown: true)
                    .font(.title2.monospacedDigit())
            }
        } else {
            Text("session.live.ready")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
extension SessionLiveActivityAttributes {
    fileprivate static var preview: SessionLiveActivityAttributes {
        SessionLiveActivityAttributes(sessionId: UUID(), goalRaw: "hypertrophy")
    }
}

extension SessionLiveActivityState {
    fileprivate static var resting: Self {
        .init(
            currentExerciseSlug: "barbell-back-squat",
            currentExerciseDisplayName: "バーベル バックスクワット",
            progress: 4,
            total: 12,
            intervalEndsAt: Date().addingTimeInterval(45)
        )
    }
    fileprivate static var ready: Self {
        .init(
            currentExerciseSlug: "bench-press",
            currentExerciseDisplayName: "ベンチプレス",
            progress: 6,
            total: 12,
            intervalEndsAt: nil
        )
    }
}

#Preview("LockScreen / resting", as: .content, using: SessionLiveActivityAttributes.preview) {
    SessionLiveActivity()
} contentStates: {
    SessionLiveActivityState.resting
    SessionLiveActivityState.ready
}
#endif
