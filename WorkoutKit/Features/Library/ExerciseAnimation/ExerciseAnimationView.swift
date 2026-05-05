// MARK: - ExerciseAnimationView
// プロトタイプ: 5 種目分のエクササイズアニメーション(SwiftUI 自前 procedural)。
// CLAUDE.md §-1 Lock により動画・Lottie 同梱なし。Canvas + TimelineView で完結。
//
// Reduce Motion (`accessibilityReduceMotion`) ON 時はアニメ停止し、
// `phase = 0.5`(中間ポーズ) を静止描画する。

import SwiftUI

/// 対応している 5 種目。
enum ExerciseAnimationKind: String, CaseIterable {
    case pushup
    case squat
    case plank
    case lunge
    case burpee

    /// seed の slug → kind マッピング。
    /// 完全一致が無くても、形状が近い派生 slug をここで吸収する。
    static func from(slug: String) -> ExerciseAnimationKind? {
        switch slug {
        case "push-up": return .pushup
        case "air-squat": return .squat
        case "plank": return .plank
        case "reverse-lunge": return .lunge
        case "burpee": return .burpee
        default: return nil
        }
    }

    var cycleDuration: TimeInterval {
        switch self {
        case .pushup: return PushupAnimation.cycleDuration
        case .squat:  return SquatAnimation.cycleDuration
        case .plank:  return PlankAnimation.cycleDuration
        case .lunge:  return LungeAnimation.cycleDuration
        case .burpee: return BurpeeAnimation.cycleDuration
        }
    }

    func pose(phase: CGFloat) -> StickFigurePose {
        switch self {
        case .pushup: return PushupAnimation.pose(phase: phase)
        case .squat:  return SquatAnimation.pose(phase: phase)
        case .plank:  return PlankAnimation.pose(phase: phase)
        case .lunge:  return LungeAnimation.pose(phase: phase)
        case .burpee: return BurpeeAnimation.pose(phase: phase)
        }
    }

    /// VoiceOver 読み上げ用キー(Localizable.xcstrings に登録)。
    var accessibilityKey: LocalizedStringKey {
        switch self {
        case .pushup: return "library.detail.animation.a11y.push-up"
        case .squat:  return "library.detail.animation.a11y.air-squat"
        case .plank:  return "library.detail.animation.a11y.plank"
        case .lunge:  return "library.detail.animation.a11y.reverse-lunge"
        case .burpee: return "library.detail.animation.a11y.burpee"
        }
    }
}

struct ExerciseAnimationView: View {
    let kind: ExerciseAnimationKind

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// `slug` から初期化。対応外 slug の場合は nil。
    init?(slug: String) {
        guard let k = ExerciseAnimationKind.from(slug: slug) else { return nil }
        self.kind = k
    }

    /// 直接 kind 指定で初期化(Preview 用)。
    init(kind: ExerciseAnimationKind) {
        self.kind = kind
    }

    var body: some View {
        ZStack {
            // 背景: 種目を引き立てる薄いグラデーション。
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundGradient)

            if reduceMotion {
                // 静止: 中間ポーズで「動きの代表」を表示。
                Canvas { context, size in
                    var ctx = context
                    StickFigure.draw(
                        kind.pose(phase: 0.5),
                        in: &ctx,
                        size: size,
                        color: figureColor
                    )
                }
                .padding(16)
            } else {
                TimelineView(.animation) { timeline in
                    let phase = phaseValue(at: timeline.date)
                    Canvas { context, size in
                        var ctx = context
                        StickFigure.draw(
                            kind.pose(phase: phase),
                            in: &ctx,
                            size: size,
                            color: figureColor
                        )
                    }
                    .padding(16)
                }
            }
        }
        .aspectRatio(1.6, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel(Text(kind.accessibilityKey))
        .accessibilityAddTraits(.isImage)
    }

    // MARK: - Phase

    private static let referenceDate = Date(timeIntervalSinceReferenceDate: 0)

    private func phaseValue(at date: Date) -> CGFloat {
        let elapsed = date.timeIntervalSince(Self.referenceDate)
        let cycle = kind.cycleDuration
        guard cycle > 0 else { return 0 }
        let normalized = elapsed.truncatingRemainder(dividingBy: cycle) / cycle
        return CGFloat(normalized)
    }

    // MARK: - Style

    private var figureColor: Color {
        // アクセントカラーは「身体」を表現するため濃いめの単色を使う。
        // light/dark どちらでもコントラストを確保。
        colorScheme == .dark ? Color(white: 0.92) : Color(white: 0.18)
    }

    private var backgroundGradient: LinearGradient {
        let top = Color.accentColor.opacity(colorScheme == .dark ? 0.20 : 0.12)
        let bottom = Color.accentColor.opacity(colorScheme == .dark ? 0.06 : 0.03)
        return LinearGradient(
            colors: [top, bottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#if DEBUG
#Preview("All animations") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(ExerciseAnimationKind.allCases, id: \.self) { kind in
                ExerciseAnimationView(kind: kind)
            }
        }
        .padding()
    }
}
#endif
