// MARK: - IntervalCountdownView
// CLAUDE.md §1.1 F-03 / §11 準拠。
// セット間休憩のカウントダウンを大きく表示する小コンポーネント。
// - SessionStore.intervalSecondsRemaining を読むだけの presentation only。
// - 残り3秒以下は警告色、それ以外はアクセントカラーで描画する。
// - SessionView の入力パネル直前に挿入する想定。

import SwiftUI

struct IntervalCountdownView: View {
    let secondsRemaining: Int

    private var isWarning: Bool { secondsRemaining <= 3 }

    /// F3: Reduce Motion 中はカウントダウン数字の transition / animation を抑制する。
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            Text("session.interval.label")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(formatted)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isWarning ? Color.orange : Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: secondsRemaining)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(.regularMaterial)
        )
        .padding(.horizontal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("session.interval.label"))
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// `MM:SS` 形式。30 秒以上は短縮表記が伝わりにくいので常に分:秒で出す。
    private var formatted: String {
        let clamped = max(0, secondsRemaining)
        let minutes = clamped / 60
        let seconds = clamped % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// `accessibilityValue` は変化したタイミングで VoiceOver が再読みする
    /// (`accessibilityLabel` は構造的に固定なので再アナウンスしない)。
    /// `.updatesFrequently` トレイトと併用して、毎秒の残り秒数を再アナウンス対象にする。
    private var accessibilityValue: Text {
        let template = String(
            localized: "session.interval.a11y",
            defaultValue: "残り %lld 秒"
        )
        return Text(String(format: template, max(0, secondsRemaining)))
    }
}

#Preview("3 seconds (warning)") {
    IntervalCountdownView(secondsRemaining: 3)
        .padding()
}

#Preview("60 seconds") {
    IntervalCountdownView(secondsRemaining: 60)
        .padding()
}
