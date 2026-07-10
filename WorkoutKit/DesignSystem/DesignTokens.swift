// MARK: - DesignTokens
// CLAUDE.md §7-2 準拠。アプリ全体で共有するデザイントークン。
//
// これまで cornerRadius(2/8/10/12/14/18)や Color.green/.red の直書きが
// 画面ごとに散らばっていたため、セマンティック層をここに一元化する。
// 新規コードは必ずこのトークンを参照すること。リテラル指定は禁止。
//
// 使い分け:
//   AppRadius.chip    — 小さなバッジ・タグ・カレンダードット
//   AppRadius.control — ボタン・入力コントロール
//   AppRadius.card    — 通常カード(リスト内カード、入力パネル)
//   AppRadius.hero    — 大型カード(人体図、Today ヒーロー、Paywall プラン)

import SwiftUI

/// セマンティックカラー。CLAUDE.md §7-2 の `enum AppColor` 実装。
/// アクセントは Assets.xcassets の AccentColor(light #FF6B35 / dark #FF8F66)。
enum AppColor {
    static let accent = Color.accentColor
    static let success = Color.green
    static let destructive = Color.red
    static let warning = Color.orange
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
}

/// 角丸の統一スケール。全て continuous corner で使うこと。
enum AppRadius {
    static let chip: CGFloat = 8
    static let control: CGFloat = 12
    static let card: CGFloat = 14
    static let hero: CGFloat = 18
}

// MARK: - Primary / Secondary CTA ButtonStyle

/// アプリ全体のプライマリ CTA。従来 5 箇所にコピペされていた
/// 「accent 背景 + 白文字 + RoundedRectangle」実装を置き換える。
/// - 押下中は 0.97 倍スケール + 微減光(ジムでも押した感覚が視認できる)
/// - 最低高さ 50pt(§11-6 の 44pt を上回るタップターゲット)
/// - Reduce Motion 時はスケールアニメを抑制
struct PrimaryCTAButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(AppColor.accent.opacity(isEnabled ? 1.0 : 0.35))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8),
                       value: configuration.isPressed)
    }
}

/// セカンダリアクション(Skip 等)。控えめな塗り + primary 文字色。
struct SecondaryCTAButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8),
                       value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryCTAButtonStyle {
    /// `Button { } label: { Text(...) }.buttonStyle(.primaryCTA)`
    static var primaryCTA: PrimaryCTAButtonStyle { PrimaryCTAButtonStyle() }
}

extension ButtonStyle where Self == SecondaryCTAButtonStyle {
    static var secondaryCTA: SecondaryCTAButtonStyle { SecondaryCTAButtonStyle() }
}

// MARK: - Stat number typography

/// 大型数値表示(§7-3「ワークアウト中の数値表示」)の統一モディファイア。
/// Dynamic Type に追従させるためテキストスタイルベース(largeTitle ≈ 34pt 基準、
/// AX サイズで自動拡大)。rounded + bold + monospacedDigit で「計器」の見た目に。
struct StatNumberModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(.largeTitle, design: .rounded).weight(.bold))
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

extension View {
    /// 重量・レップ・週間ボリューム等の主役数値に適用する。
    func statNumber() -> some View {
        modifier(StatNumberModifier())
    }
}
