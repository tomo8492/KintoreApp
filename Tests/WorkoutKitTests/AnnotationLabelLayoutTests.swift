// MARK: - AnnotationLabelLayoutTests
// CLAUDE.md §1.1 F-02 / §11.4 準拠。
// AnnotationLabelLayout.resolve(...) がカードの重なりを最小化することを Swift Testing で凍結する。

import Foundation
import Testing
@testable import WorkoutKit

@Suite("AnnotationLabelLayout")
struct AnnotationLabelLayoutTests {

    private static let canvas = CGSize(width: 360, height: 320)

    static func makeLabel(
        id: String,
        anchor: AnnotationPoint,
        position: AnnotationPoint = AnnotationPoint(x: 0.21, y: 0.30),
        key: String? = nil
    ) -> AnnotationLabel {
        AnnotationLabel(
            id: id,
            position: position,
            labelAnchor: anchor,
            labelKey: key ?? "dummy.\(id)",
            color: .info
        )
    }

    @Test("labels が空なら空配列を返す")
    func emptyInput() {
        let result = AnnotationLabelLayout.resolve(
            labels: [],
            canvasSize: Self.canvas,
            fontSize: 11
        )
        #expect(result.isEmpty)
    }

    @Test("入力 labels の順序を保って返す")
    func preservesInputOrder() {
        let labels = [
            Self.makeLabel(id: "A", anchor: AnnotationPoint(x: 0.04, y: 0.10)),
            Self.makeLabel(id: "B", anchor: AnnotationPoint(x: 0.96, y: 0.50)),
            Self.makeLabel(id: "C", anchor: AnnotationPoint(x: 0.04, y: 0.80))
        ]
        let result = AnnotationLabelLayout.resolve(
            labels: labels,
            canvasSize: Self.canvas,
            fontSize: 11
        )
        #expect(result.map(\.labelId) == ["A", "B", "C"])
    }

    @Test("同一サイドで近接する 2 ラベルは衝突しない位置に解決される")
    func sameSideLabelsDoNotOverlap() {
        // どちらも左サイド、同じ y(35%)に置きたいケース。
        let labels = [
            Self.makeLabel(id: "left-top", anchor: AnnotationPoint(x: 0.04, y: 0.35)),
            Self.makeLabel(id: "left-too", anchor: AnnotationPoint(x: 0.04, y: 0.36))
        ]
        let result = AnnotationLabelLayout.resolve(
            labels: labels,
            canvasSize: Self.canvas,
            fontSize: 11
        )
        #expect(result.count == 2)
        let inter = result[0].cardRect.intersection(result[1].cardRect)
        // 衝突マージンを超える重なりは無いこと(完全交差は許容しない)
        let overlapArea = max(0, inter.width) * max(0, inter.height)
        #expect(overlapArea == 0, "expected no overlap, got area=\(overlapArea)")
    }

    @Test("カードが画面右端を超えないようにクランプされる")
    func rightEdgeIsRespected() {
        // 右サイド anchor(0.98)に長文を置こうとしても画面外に出ないこと。
        let labels = [
            Self.makeLabel(id: "wide-right",
                      anchor: AnnotationPoint(x: 0.98, y: 0.50))
        ]
        let result = AnnotationLabelLayout.resolve(
            labels: labels,
            canvasSize: Self.canvas,
            fontSize: 11
        )
        #expect(result.count == 1)
        let r = result[0].cardRect
        #expect(r.minX >= 0 - 0.5)
        #expect(r.maxX <= Self.canvas.width + 0.5)
        #expect(r.minY >= 0 - 0.5)
        #expect(r.maxY <= Self.canvas.height + 0.5)
    }

    @Test("isLeftSide フラグが anchor.x の左右で正しく決まる")
    func leftSideFlag() {
        let labels = [
            Self.makeLabel(id: "L", anchor: AnnotationPoint(x: 0.04, y: 0.20)),
            Self.makeLabel(id: "R", anchor: AnnotationPoint(x: 0.95, y: 0.50))
        ]
        let result = AnnotationLabelLayout.resolve(
            labels: labels,
            canvasSize: Self.canvas,
            fontSize: 11
        )
        let lookup = Dictionary(uniqueKeysWithValues: result.map { ($0.labelId, $0) })
        #expect(lookup["L"]?.isLeftSide == true)
        #expect(lookup["R"]?.isLeftSide == false)
    }

    @Test("引き出し線の終点は左サイドならカード左辺、右サイドならカード右辺")
    func leaderEndIsAtNearestEdge() {
        let labels = [
            Self.makeLabel(id: "L", anchor: AnnotationPoint(x: 0.04, y: 0.20)),
            Self.makeLabel(id: "R", anchor: AnnotationPoint(x: 0.95, y: 0.50))
        ]
        let result = AnnotationLabelLayout.resolve(
            labels: labels,
            canvasSize: Self.canvas,
            fontSize: 11
        )
        let lookup = Dictionary(uniqueKeysWithValues: result.map { ($0.labelId, $0) })
        if let l = lookup["L"] {
            #expect(abs(l.leaderEnd.x - l.cardRect.minX) < 0.01)
            #expect(abs(l.leaderEnd.y - l.cardRect.midY) < 0.01)
        }
        if let r = lookup["R"] {
            #expect(abs(r.leaderEnd.x - r.cardRect.maxX) < 0.01)
            #expect(abs(r.leaderEnd.y - r.cardRect.midY) < 0.01)
        }
    }

    @Test("3 ラベルが同 y に集中しても全て衝突なく配置される")
    func threeStackedAreAllPlaced() {
        let labels = [
            Self.makeLabel(id: "A", anchor: AnnotationPoint(x: 0.04, y: 0.40)),
            Self.makeLabel(id: "B", anchor: AnnotationPoint(x: 0.04, y: 0.41)),
            Self.makeLabel(id: "C", anchor: AnnotationPoint(x: 0.04, y: 0.42))
        ]
        let result = AnnotationLabelLayout.resolve(
            labels: labels,
            canvasSize: Self.canvas,
            fontSize: 11
        )
        #expect(result.count == 3)
        for i in 0..<result.count {
            for j in (i+1)..<result.count {
                let inter = result[i].cardRect.intersection(result[j].cardRect)
                let area = max(0, inter.width) * max(0, inter.height)
                #expect(area == 0,
                        "labels \(result[i].labelId) and \(result[j].labelId) overlap area=\(area)")
            }
        }
    }
}
