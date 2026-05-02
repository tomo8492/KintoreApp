// MARK: - AutoScrollEffect
// CLAUDE.md §1.1 F-03 / §11 準拠。
// workout-cool PR #57 相当の「現在実施中の種目を自動で画面中央へスクロール」挙動を
// SwiftUI で実装するための ViewModifier。
// - ScrollViewReader 配下で使う
// - .task(id:) を使い currentId が変わるたびに proxy.scrollTo(_:anchor:) を呼ぶ
// - 起動直後の意図しないスクロールを避けるため、最初の発火だけは無アニメーションで実行する

import SwiftUI

private struct AutoScrollEffectModifier<ID: Hashable>: ViewModifier {
    let proxy: ScrollViewProxy
    let currentId: ID
    let anchor: UnitPoint

    @State private var hasRunInitialScroll = false
    /// F3: Reduce Motion が有効な時はアニメーションでのスクロールを避ける。
    /// 初回スクロール(無アニメ)は実施するが、以降のアニメ付きスクロールは無効化する。
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .task(id: currentId) {
                if hasRunInitialScroll {
                    if reduceMotion {
                        // Reduce Motion: 切替えはあるがアニメーションは省く。
                        proxy.scrollTo(currentId, anchor: anchor)
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(currentId, anchor: anchor)
                        }
                    }
                } else {
                    // 初回はアニメ無し(View 構築直後の固定スクロール)
                    proxy.scrollTo(currentId, anchor: anchor)
                    hasRunInitialScroll = true
                }
            }
    }
}

extension View {
    /// ScrollViewReader 内で使い、`currentId` が変わるたびに該当行へ自動スクロールする。
    /// 例:
    /// ```swift
    /// ScrollViewReader { proxy in
    ///     List(items) { ... }.id(...)
    ///         .autoScrollToCurrent(proxy: proxy, currentId: store.currentItemId)
    /// }
    /// ```
    func autoScrollToCurrent<ID: Hashable>(
        proxy: ScrollViewProxy,
        currentId: ID,
        anchor: UnitPoint = .center
    ) -> some View {
        modifier(AutoScrollEffectModifier(proxy: proxy, currentId: currentId, anchor: anchor))
    }
}
