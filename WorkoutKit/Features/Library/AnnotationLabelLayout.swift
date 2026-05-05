// MARK: - AnnotationLabelLayout
// AnnotationLabelOverlay の補助。各テキストカードの実寸を UIKit の
// NSAttributedString.boundingRect で計測し、JSON で指定された labelAnchor を
// 出発点として greedy に衝突回避(垂直方向にずらす)した最終配置を返す。
//
// 設計指針(CLAUDE.md §-1.6 / NG リスト):
//   - 純データ計算。SwiftUI に依存しない(View 単体テストできるよう)
//   - 入力 labels の順番をそのまま返す(描画安定のため)
//   - 失敗しない: 計測不能でも空配列を返してフォールバック
//
// 衝突回避方針:
//   - JSON 指定の labelAnchor を「希望位置」として尊重
//   - 同一サイドで重なる場合のみ垂直オフセット候補を試す
//     候補: 0, ±5%, ±10%, ±15%, ±20%, ±25%(canvas height 比)
//   - 画面外にはみ出す候補はペナルティを大きくして回避
//   - 衝突量(矩形交差面積)+ 希望 y からの距離(微小重み) でスコア最小化

import Foundation
import UIKit

/// 1 ラベルの最終配置(ピクセル座標、左上原点)。
struct ResolvedLabelPlacement: Equatable {
    let labelId: String
    let cardRect: CGRect
    let dotPosition: CGPoint
    /// 引き出し線のカード側終点(カードの最も人体側の辺中央に揃える)。
    let leaderEnd: CGPoint
    let color: AnnotationColor
    let labelKey: String
    let isLeftSide: Bool
}

enum AnnotationLabelLayout {

    static let cardHorizontalPadding: CGFloat = 12  // 6 + 6
    static let cardVerticalPadding: CGFloat = 8     // 4 + 4
    /// 最大カード幅(canvas 比)。LabelCard の `.frame(maxWidth:)` と一致させる。
    static let maxCardWidthRatio: CGFloat = 0.42
    /// 衝突マージン(px)。視覚的な近接も避けたいため、計測サイズに上乗せして衝突判定する。
    static let collisionMargin: CGFloat = 4

    static func resolve(
        labels: [AnnotationLabel],
        canvasSize: CGSize,
        fontSize: CGFloat,
        bundle: Bundle = .main
    ) -> [ResolvedLabelPlacement] {
        guard canvasSize.width > 0, canvasSize.height > 0, !labels.isEmpty else {
            return []
        }

        let maxCardWidth = max(40, canvasSize.width * maxCardWidthRatio)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let textAttrs: [NSAttributedString.Key: Any] = [.font: font]

        // Step 1: 各ラベルの希望矩形を計算する(サイズは実テキスト計測)。
        let prelim: [Preliminary] = labels.map { label in
            let resolvedText = bundle.localizedString(
                forKey: label.labelKey, value: nil, table: nil
            )
            let bounding = (resolvedText as NSString).boundingRect(
                with: CGSize(width: maxCardWidth - cardHorizontalPadding,
                             height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: textAttrs,
                context: nil
            )
            let textW = ceil(bounding.width)
            let textH = ceil(bounding.height)
            let cardSize = CGSize(
                width: min(maxCardWidth, textW + cardHorizontalPadding),
                height: textH + cardVerticalPadding
            )

            let isLeft = label.labelAnchor.x < 0.5
            let anchorPx = CGPoint(
                x: label.labelAnchor.x * canvasSize.width,
                y: label.labelAnchor.y * canvasSize.height
            )
            let originX: CGFloat
            if isLeft {
                originX = anchorPx.x
            } else {
                originX = anchorPx.x - cardSize.width
            }
            let originY = anchorPx.y - cardSize.height * 0.5
            let preferredRect = CGRect(origin: CGPoint(x: originX, y: originY), size: cardSize)

            return Preliminary(
                label: label,
                cardSize: cardSize,
                isLeftSide: isLeft,
                preferredAnchorPx: anchorPx,
                preferredRect: preferredRect
            )
        }

        // Step 2: 希望 y 順に貪欲配置(早く決まる方がレイアウト安定)。
        // ただし返却順は元の labels 順序を維持する。
        let yOrdered = prelim.enumerated().sorted { lhs, rhs in
            lhs.element.preferredRect.midY < rhs.element.preferredRect.midY
        }

        // 候補オフセット(canvas height 比)。0 から ±25% まで。
        let normalizedOffsets: [CGFloat] = [
            0,
            -0.05, 0.05,
            -0.10, 0.10,
            -0.15, 0.15,
            -0.20, 0.20,
            -0.25, 0.25
        ]

        // 配置済みカードの矩形(衝突マージン込みで判定するため、判定時に inset する)。
        var placedRects: [CGRect] = []

        // 元の labels 順に対応する resolved を入れる箱。
        var resolvedByIndex = [Int: ResolvedLabelPlacement]()
        resolvedByIndex.reserveCapacity(prelim.count)

        for (originalIndex, item) in yOrdered {
            let preferred = item.preferredRect
            let preferredMidY = preferred.midY

            var bestRect = preferred
            var bestPenalty = penalty(
                of: preferred,
                against: placedRects,
                canvasSize: canvasSize,
                preferredMidY: preferredMidY
            )

            for ratio in normalizedOffsets where ratio != 0 {
                let dy = ratio * canvasSize.height
                let candidate = preferred.offsetBy(dx: 0, dy: dy)
                let p = penalty(
                    of: candidate,
                    against: placedRects,
                    canvasSize: canvasSize,
                    preferredMidY: preferredMidY
                )
                if p < bestPenalty {
                    bestPenalty = p
                    bestRect = candidate
                    if p == 0 { break }
                }
            }

            // 画面端をはみ出す場合は最後にクランプ(完全にはみ出すペナルティを許容するなら
            // 最低でも見える位置に押し込む)。
            bestRect = clamp(bestRect, in: canvasSize)
            placedRects.append(bestRect)

            let leaderEnd: CGPoint
            if item.isLeftSide {
                leaderEnd = CGPoint(x: bestRect.minX, y: bestRect.midY)
            } else {
                leaderEnd = CGPoint(x: bestRect.maxX, y: bestRect.midY)
            }
            let dotPx = CGPoint(
                x: item.label.position.x * canvasSize.width,
                y: item.label.position.y * canvasSize.height
            )

            resolvedByIndex[originalIndex] = ResolvedLabelPlacement(
                labelId: item.label.id,
                cardRect: bestRect,
                dotPosition: dotPx,
                leaderEnd: leaderEnd,
                color: item.label.color,
                labelKey: item.label.labelKey,
                isLeftSide: item.isLeftSide
            )
        }

        return (0..<prelim.count).compactMap { resolvedByIndex[$0] }
    }

    // MARK: - Penalty

    private static func penalty(
        of rect: CGRect,
        against placed: [CGRect],
        canvasSize: CGSize,
        preferredMidY: CGFloat
    ) -> CGFloat {
        var p: CGFloat = 0

        // 画面外(重ペナルティ)
        if rect.minX < 0       { p += -rect.minX * 50 }
        if rect.minY < 0       { p += -rect.minY * 50 }
        if rect.maxX > canvasSize.width  { p += (rect.maxX - canvasSize.width)  * 50 }
        if rect.maxY > canvasSize.height { p += (rect.maxY - canvasSize.height) * 50 }

        // 既存カードとの衝突(マージン込み)
        let inflated = rect.insetBy(dx: -collisionMargin, dy: -collisionMargin)
        for q in placed {
            let inter = inflated.intersection(q.insetBy(dx: -collisionMargin, dy: -collisionMargin))
            if !inter.isNull && inter.width > 0 && inter.height > 0 {
                p += inter.width * inter.height
            }
        }

        // 希望位置から離れるほど微小ペナルティ(衝突回避を最小限のずれで)
        p += abs(rect.midY - preferredMidY) * 0.05
        return p
    }

    private static func clamp(_ rect: CGRect, in canvas: CGSize) -> CGRect {
        var r = rect
        if r.minX < 0 { r.origin.x = 0 }
        if r.minY < 0 { r.origin.y = 0 }
        if r.maxX > canvas.width  { r.origin.x = canvas.width  - r.size.width }
        if r.maxY > canvas.height { r.origin.y = canvas.height - r.size.height }
        // どうしてもはみ出す(canvas より大きい)場合は左上クランプを優先。
        if r.minX < 0 { r.origin.x = 0 }
        if r.minY < 0 { r.origin.y = 0 }
        return r
    }

    // MARK: - Helper struct

    private struct Preliminary {
        let label: AnnotationLabel
        let cardSize: CGSize
        let isLeftSide: Bool
        let preferredAnchorPx: CGPoint
        let preferredRect: CGRect
    }
}
