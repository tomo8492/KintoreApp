// MARK: - ExerciseAnimationView
// sample/2d-lottie-prototype: Lottie 版のエクササイズアニメーション(5 種目)。
//
// 設計:
//   1. `Resources/Lottie/<slug>.json` が Bundle にあれば Lottie で再生(主)。
//   2. 無ければ既存の SwiftUI procedural(StickFigure)で fallback(副)。
// これにより「Lottie 経路の検証」を最優先しつつ、未配置 slug でも
// 動作を保証する(ANIMATION_RESEARCH.md オプション D ハイブリッド)。
//
// `Reduce Motion` ON 時:
//   - Lottie パス: progress=0.5 で静止描画(中間ポーズ)。
//   - procedural パス: 既存どおり phase=0.5 を Canvas で静止描画。

import SwiftUI
import Lottie

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

    /// Bundle にある Lottie JSON のリソース名(`Resources/Lottie/<slug>.json`)。
    var lottieResourceName: String {
        switch self {
        case .pushup: return "push-up"
        case .squat:  return "air-squat"
        case .plank:  return "plank"
        case .lunge:  return "reverse-lunge"
        case .burpee: return "burpee"
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
    /// Bundle で見つかった Lottie アニメーション。nil の場合は procedural fallback。
    private let lottieAnimation: LottieAnimation?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// `slug` から初期化。対応外 slug の場合は nil。
    init?(slug: String) {
        guard let k = ExerciseAnimationKind.from(slug: slug) else { return nil }
        self.kind = k
        self.lottieAnimation = LottieAnimation.named(k.lottieResourceName, bundle: .main)
    }

    /// 直接 kind 指定で初期化(Preview 用)。
    init(kind: ExerciseAnimationKind) {
        self.kind = kind
        self.lottieAnimation = LottieAnimation.named(kind.lottieResourceName, bundle: .main)
    }

    var body: some View {
        ZStack {
            // 背景: 種目を引き立てる薄いグラデーション。
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundGradient)

            content
                .padding(16)
        }
        .aspectRatio(1.6, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel(Text(kind.accessibilityKey))
        .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private var content: some View {
        if let lottieAnimation {
            lottieView(animation: lottieAnimation)
        } else {
            proceduralView
        }
    }

    // MARK: - Lottie path

    private func lottieView(animation: LottieAnimation) -> some View {
        // Lottie の Stroke カラーは JSON 内で 0,0,0,1(黒)で出力済み。
        // ColorValueProvider で身体線の色を colorScheme に合わせて上書きする。
        let valueProvider = ColorValueProvider(figureLottieColor.lottieColorValue)

        // Lottie 系の chain は LottieView 自身を返す前に閉じる必要がある
        // (.aspectRatio() は SwiftUI の some View を返してしまうため)。
        let baseView = LottieView(animation: animation)
            .resizable()
            .configure { lottieAnimationView in
                // Stroke の Color を全レイヤ共通で上書き。
                // Bone / Head 両レイヤの Stroke を狙う。
                lottieAnimationView.setValueProvider(
                    valueProvider,
                    keypath: AnimationKeypath(keypath: "**.Stroke 1.Color")
                )
            }

        let configured = reduceMotion
            ? baseView.currentProgress(0.5)        // 中間ポーズで静止
            : baseView.looping()                   // 0→1 を無限ループ

        return configured
            .aspectRatio(contentMode: .fit)
    }

    // MARK: - Procedural fallback

    @ViewBuilder
    private var proceduralView: some View {
        if reduceMotion {
            Canvas { context, size in
                var ctx = context
                StickFigure.draw(
                    kind.pose(phase: 0.5),
                    in: &ctx,
                    size: size,
                    color: figureColor
                )
            }
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
            }
        }
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

    /// procedural Canvas 用の図形色。
    private var figureColor: Color {
        colorScheme == .dark ? Color(white: 0.92) : Color(white: 0.18)
    }

    /// Lottie 用の図形色。Lottie の Color 値は 0..1 の RGB を期待するため
    /// `ColorValueProvider(.init(...))` 経由で変換する。
    private var figureLottieColor: UIColor {
        colorScheme == .dark
            ? UIColor(white: 0.92, alpha: 1.0)
            : UIColor(white: 0.18, alpha: 1.0)
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

// MARK: - UIColor → Lottie.Color

private extension UIColor {
    /// Lottie の `LottieColor` を取得する。0..1 の RGBA。
    var lottieColorValue: LottieColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return LottieColor(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
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
