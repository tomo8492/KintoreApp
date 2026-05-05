// MARK: - ExerciseAnnotation
// 種目ごとの「動作矢印 + 引き出し線付きアノテーション」データ。
// 純データ型であり、SwiftUI 描画ロジックは AnnotatedBodyDiagramView に置く。
//
// 座標系:
//   x, y は正規化済み (0.0 ... 1.0)。原点は左上、x は右方向、y は下方向。
//   解剖学人体図 SVG (viewBox 535×462, body-base.svg) の表示領域上での
//   相対位置として解釈される。SVG は前面(左)・背面(右)が左右に並ぶため、
//   - 前面体: 概ね x ∈ [0.04, 0.46]
//   - 背面体: 概ね x ∈ [0.54, 0.96]
//   y は頭頂 0.0、つま先 1.0。
//
// 配置ガイド:
//   - position は人体図上の解剖学的なターゲット位置(関節・筋腹など)
//   - labelAnchor はテキストカードを描画する位置(画面端寄せが見やすい)
//
// JSON は Resources/BodyAnnotations/<slug>.json に1ファイル1種目で配置する。

import Foundation

struct ExerciseAnnotation: Decodable, Sendable, Equatable {
    let slug: String
    let view: AnnotationView
    let arrows: [AnnotationArrow]
    let annotations: [AnnotationLabel]
}

enum AnnotationView: String, Decodable, Sendable, Equatable {
    case front
    case back
    case side
}

struct AnnotationPoint: Decodable, Sendable, Equatable {
    let x: Double
    let y: Double
}

enum AnnotationCurve: String, Decodable, Sendable, Equatable {
    case straight
    case curved
}

/// 強調色のセマンティクス。実際の色は AnnotatedBodyDiagramView で
/// SwiftUI の Color に解決する(ダーク/ライト両対応)。
enum AnnotationColor: String, Decodable, Sendable, Equatable {
    case primary  // 主動作 / メイン強調
    case info     // 補助・注意ポイント
    case warning  // 危険な可動域
    case success  // 良いフォーム指示
}

struct AnnotationArrow: Decodable, Sendable, Equatable {
    let id: String
    let from: AnnotationPoint
    let to: AnnotationPoint
    let curve: AnnotationCurve
    let color: AnnotationColor
}

struct AnnotationLabel: Decodable, Sendable, Equatable {
    let id: String
    let position: AnnotationPoint
    let labelAnchor: AnnotationPoint
    /// `Localizable.xcstrings` のキー。AnnotatedBodyDiagramView 側で
    /// LocalizedStringKey として解決される。
    let labelKey: String
    let color: AnnotationColor
}
