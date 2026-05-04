// MARK: - BodyHitZones
// Builder F-01 視覚版ピッカーのタップ判定領域。workout-cool (MIT) の
// muscle-selection.tsx 由来 SVG (viewBox 0 0 535 462) の各筋肉パスの
// バウンディングボックスを使う。生成元: scripts/extract_body_svg.py
//
// SVG の前面/背面が左右に並ぶレイアウトのため、左右の同種筋肉
// (例: 上腕二頭筋・大腿四頭筋) は1つの bbox に統合されている。
// 解剖学的に front/back の両側にある筋肉(僧帽筋・三角筋・前腕)は
// 横長の bbox を持つ。視覚オーバーレイ SVG が両側を highlight する
// ため、1タップで両側を一括選択できる(意図した挙動)。

import Foundation

enum BodyHitZones {

    /// (x, y, width, height) を viewBox 535×462 座標系で。
    static let zones: [Muscle: CGRect] = [
        .chest:      CGRect(x:  72.5, y:  82.9, width:  83.5, height:  44.9),
        .lats:       CGRect(x: 367.2, y:  92.8, width:  89.8, height: 118.1),
        .traps:      CGRect(x:  76.2, y:  37.5, width: 373.7, height: 105.4),
        .deltoids:   CGRect(x:  48.5, y:  76.5, width: 428.2, height:  42.0),
        .biceps:     CGRect(x:  41.2, y: 110.5, width: 147.5, height:  57.5),
        .triceps:    CGRect(x: 339.5, y: 108.1, width: 143.3, height:  47.2),
        .forearms:   CGRect(x:  20.0, y: 145.0, width: 490.2, height:  82.0),
        .abs:        CGRect(x:  92.8, y: 120.8, width:  44.2, height: 104.0),
        .obliques:   CGRect(x:  74.0, y: 115.5, width:  81.2, height: 105.2),
        .lowerBack:  CGRect(x: 388.0, y: 186.0, width:  46.0, height:  38.0),
        .quadriceps: CGRect(x:  64.2, y: 190.5, width: 103.2, height: 147.0),
        .hamstrings: CGRect(x: 362.0, y: 208.8, width:  99.0, height: 132.5),
        .glutes:     CGRect(x: 366.2, y: 185.8, width:  89.5, height:  55.5),
        .calves:     CGRect(x:  68.2, y: 307.8, width: 393.5, height: 120.5),
    ]

    /// 重なりが起きるとき、より小さい(=固有性が高い)領域を優先したいので
    /// 面積の昇順で並べる。ZStack 順は「先=下、後=上」なので、面積大→小の順に enumerate する。
    static let orderedFromLargestToSmallest: [Muscle] = {
        zones.keys.sorted { lhs, rhs in
            (zones[lhs]?.area ?? 0) > (zones[rhs]?.area ?? 0)
        }
    }()

    /// SVG の論理サイズ。
    static let viewBox = CGSize(width: 535, height: 462)
}

private extension CGRect {
    var area: CGFloat { width * height }
}
