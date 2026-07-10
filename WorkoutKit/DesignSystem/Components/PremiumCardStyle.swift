// MARK: - PremiumCardStyle
// 人体図カード共通の "quiet luxury" スタイル(CLAUDE.md §7 デザイン原則 準拠)。
// レイヤード感・ヘアラインストローク・控えめなグラデーションで、
// 派手な装飾に頼らないプレミアム感を出す。
//
// 適用対象:
//   - BodySectionView (Library detail, 前面/後面カード)
//   - BodyDiagramView (Builder, タップ可能な筋肉ピッカー)
//
// CLAUDE.md NG リスト:
//   - print/force unwrap/.shared なし
//   - Dynamic Type 対応のため固定 pt フォントは使わない
//     (本ファイルはコンテナ装飾のみでテキストは扱わないが、
//      GradientNumberBadge のラベルはテキストスタイルベースにする)

import SwiftUI

// MARK: - Card background / border / shadow

/// 人体図を収めるカードの背景・ヘアライン境界線・影をまとめた ViewModifier。
/// カード自体に padding は含まない(呼び出し側でコンテンツ padding を制御する)。
struct PremiumDiagramCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .background(cardBackground)
            .overlay(cardBorder)
            .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 6)
    }

    /// システム背景色の縦グラデーション + トルソ裏に忍ばせるアクセントの
    /// radial gradient(0.06 opacity, ほぼ気配のみ)。
    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.06), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 220
                    )
                )
        }
    }

    /// ダークモードでは edge-light、ライトモードではほぼ不可視になる
    /// ヘアラインボーダー。
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.25), .white.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.75
            )
    }
}

extension View {
    /// 人体図カードの premium 背景・境界線・影を適用する。
    func premiumDiagramCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(PremiumDiagramCardStyle(cornerRadius: cornerRadius))
    }
}

// MARK: - Numbered badge

/// 人体図上のドット / キューリストの丸数字に共通で使う "on-brand gradient" バッジ。
/// セマンティックカラー(primary/info/warning/success)は呼び出し側から渡された
/// `color` をそのまま基調にする(意味を保ったままグラデーション化するため、
/// 一律 accentColor には固定しない)。
struct GradientNumberBadge: View {
    let number: Int
    let color: Color
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1.5)

            Text(String(number))
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - Muscle highlight glow

/// 主動筋ハイライト層にのみ使う微光。SVG に色が焼き込まれているアセットでも
/// レイヤー全体に shadow を掛けることでグロー効果を再現できる。
/// ReduceTransparency / Increase Contrast が有効なときは視認性を優先し、
/// グローを無効化する。
struct MuscleGlowModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content
        } else {
            content.shadow(color: Color.accentColor.opacity(0.45), radius: 6)
        }
    }
}

extension View {
    /// 主動筋(選択中/primary)のハイライト画像レイヤーに掛ける premium グロー。
    func premiumMuscleGlow() -> some View {
        modifier(MuscleGlowModifier())
    }
}
