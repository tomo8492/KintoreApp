// MARK: - LottieGalleryDebugView
// sample/2d-lottie-prototype 用の使い捨て DEBUG 画面。
//
// 起動引数 `--lottie-gallery` で WorkoutKitApp.rootContent から差し替えて表示する。
// 5 種目の ExerciseAnimationView をスクロールで並べ、tomo / レビュアー / スクリーン
// ショット用途で「Lottie 経路の見栄え」を一画面で確認できるようにする。

#if DEBUG
import SwiftUI

struct LottieGalleryDebugView: View {
    /// 環境変数 `WK_LOTTIE_ONLY=<slug>` で 1 種目のみ拡大表示する。
    /// 指定が無ければ 5 種目をスクロールで並べる(全体ビュー)。
    /// 環境変数経由にしているのは simctl launch の引数解釈を回避するため。
    private static var focusedKind: ExerciseAnimationKind? {
        guard let slug = ProcessInfo.processInfo.environment["WK_LOTTIE_ONLY"],
              !slug.isEmpty else {
            return nil
        }
        return ExerciseAnimationKind.from(slug: slug)
    }

    var body: some View {
        if let kind = Self.focusedKind {
            focusedView(kind: kind)
        } else {
            gridView
        }
    }

    /// 5 種目をスクロールで並べる(画面に収まる小さい縦長カード形)。
    private var gridView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Lottie Animation Gallery (DEBUG)")
                    .font(.title3.bold())
                    .padding(.top)
                ForEach(ExerciseAnimationKind.allCases, id: \.self) { kind in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(kind.lottieResourceName)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("lottie.label.\(kind.lottieResourceName)")
                        ExerciseAnimationView(kind: kind)
                            .accessibilityIdentifier("lottie.view.\(kind.lottieResourceName)")
                    }
                }
            }
            .padding()
        }
    }

    /// 1 種目を縦中央に拡大表示。スクリーンショット取得用。
    private func focusedView(kind: ExerciseAnimationKind) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Text(kind.lottieResourceName)
                .font(.title3.monospaced().bold())
                .accessibilityIdentifier("lottie.focused.label")
            ExerciseAnimationView(kind: kind)
                .padding(.horizontal)
                .accessibilityIdentifier("lottie.focused.view")
            Spacer()
        }
    }
}

#Preview {
    LottieGalleryDebugView()
}
#endif
