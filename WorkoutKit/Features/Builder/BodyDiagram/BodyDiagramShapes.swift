// MARK: - BodyDiagramShapes
// Builder F-01 / 部位選択UI 視覚版。人体シルエット + 各筋肉領域の SwiftUI Path 定義。
//
// 設計方針:
// - 解剖学的精度より「タップで部位が選べる」UX を優先(CLAUDE.md §11 / 本タスク要件)。
// - 設計時の論理座標系は 200×420(viewBox 相当)。表示時は GeometryReader で fit-scale。
// - 14 部位 × 前/後 = 約 28 領域だが、片側ペアは1つの Path に左右両方を含めて
//   「胸=1 Path, 二頭=1 Path(左右)」の単位で扱う(タップ対象は muscle 単位)。
// - 座標値はマジックナンバーだが、解剖学的レイアウトはコメントで意図を明示する。

import SwiftUI

// MARK: - Side

/// 表示する人体図の面。
enum BodySide: String, CaseIterable, Identifiable, Sendable {
    case front
    case back

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .front: return "builder.muscle.diagram.side.front"
        case .back:  return "builder.muscle.diagram.side.back"
        }
    }
}

// MARK: - Layout constants

enum BodyLayout {
    static let designWidth: CGFloat = 200
    static let designHeight: CGFloat = 420
    static let designSize = CGSize(width: designWidth, height: designHeight)
}

// MARK: - Silhouette (人体シルエット背景)

/// 人体シルエット(輪郭)。前面・後面で同一の見た目で十分(影/輪郭のみ)。
struct BodySilhouetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        scaled(rect: rect) { p in
            // 頭(円)
            p.addEllipse(in: CGRect(x: 78, y: 12, width: 44, height: 50))
            // 首
            p.addRect(CGRect(x: 90, y: 58, width: 20, height: 14))
            // 胴体(肩から腰まで)。台形を擬似的に4辺で。
            p.move(to: CGPoint(x: 56, y: 78))           // 左肩
            p.addLine(to: CGPoint(x: 144, y: 78))       // 右肩
            p.addLine(to: CGPoint(x: 138, y: 200))      // 右腰
            p.addLine(to: CGPoint(x: 62, y: 200))       // 左腰
            p.closeSubpath()
            // 腰下〜骨盤
            p.addRect(CGRect(x: 66, y: 200, width: 68, height: 22))
            // 左腕(上腕→前腕)
            p.move(to: CGPoint(x: 56, y: 78))
            p.addLine(to: CGPoint(x: 32, y: 90))
            p.addLine(to: CGPoint(x: 28, y: 235))
            p.addLine(to: CGPoint(x: 50, y: 235))
            p.addLine(to: CGPoint(x: 60, y: 90))
            p.closeSubpath()
            // 右腕(対称)
            p.move(to: CGPoint(x: 144, y: 78))
            p.addLine(to: CGPoint(x: 168, y: 90))
            p.addLine(to: CGPoint(x: 172, y: 235))
            p.addLine(to: CGPoint(x: 150, y: 235))
            p.addLine(to: CGPoint(x: 140, y: 90))
            p.closeSubpath()
            // 左脚
            p.move(to: CGPoint(x: 66, y: 222))
            p.addLine(to: CGPoint(x: 96, y: 222))
            p.addLine(to: CGPoint(x: 92, y: 405))
            p.addLine(to: CGPoint(x: 70, y: 405))
            p.closeSubpath()
            // 右脚
            p.move(to: CGPoint(x: 104, y: 222))
            p.addLine(to: CGPoint(x: 134, y: 222))
            p.addLine(to: CGPoint(x: 130, y: 405))
            p.addLine(to: CGPoint(x: 108, y: 405))
            p.closeSubpath()
        }
    }
}

// MARK: - Front muscles

/// 前面に表示する筋肉領域。`muscle` は Domain Muscle にマップ。
enum FrontMuscleRegion: CaseIterable {
    case chest
    case deltoids
    case biceps
    case forearms
    case abs
    case obliques
    case quadriceps

    var muscle: Muscle {
        switch self {
        case .chest:      return .chest
        case .deltoids:   return .deltoids
        case .biceps:     return .biceps
        case .forearms:   return .forearms
        case .abs:        return .abs
        case .obliques:   return .obliques
        case .quadriceps: return .quadriceps
        }
    }

    func path(in rect: CGRect) -> Path {
        scaled(rect: rect) { p in
            switch self {
            case .chest:
                // 左右の胸筋(楕円2つ)
                p.addEllipse(in: CGRect(x: 60, y: 84, width: 38, height: 32))
                p.addEllipse(in: CGRect(x: 102, y: 84, width: 38, height: 32))
            case .deltoids:
                // 肩(三角筋前部、左右)
                p.addEllipse(in: CGRect(x: 44, y: 78, width: 24, height: 24))
                p.addEllipse(in: CGRect(x: 132, y: 78, width: 24, height: 24))
            case .biceps:
                // 上腕前面(左右)
                p.addEllipse(in: CGRect(x: 36, y: 105, width: 22, height: 50))
                p.addEllipse(in: CGRect(x: 142, y: 105, width: 22, height: 50))
            case .forearms:
                // 前腕(左右)。前面・後面で同じ位置に置く。
                p.addEllipse(in: CGRect(x: 30, y: 160, width: 22, height: 70))
                p.addEllipse(in: CGRect(x: 148, y: 160, width: 22, height: 70))
            case .abs:
                // 腹直筋(中央矩形 + 6 パック演出)
                p.addRoundedRect(
                    in: CGRect(x: 84, y: 122, width: 32, height: 78),
                    cornerSize: CGSize(width: 6, height: 6)
                )
            case .obliques:
                // 腹斜筋(両側面の細い領域)
                p.addRect(CGRect(x: 64, y: 130, width: 18, height: 65))
                p.addRect(CGRect(x: 118, y: 130, width: 18, height: 65))
            case .quadriceps:
                // 大腿四頭筋(左右)
                p.addEllipse(in: CGRect(x: 68, y: 224, width: 28, height: 80))
                p.addEllipse(in: CGRect(x: 104, y: 224, width: 28, height: 80))
            }
        }
    }
}

// MARK: - Back muscles

/// 後面に表示する筋肉領域。
enum BackMuscleRegion: CaseIterable {
    case traps
    case deltoids
    case triceps
    case forearms
    case lats
    case lowerBack
    case glutes
    case hamstrings
    case calves

    var muscle: Muscle {
        switch self {
        case .traps:      return .traps
        case .deltoids:   return .deltoids
        case .triceps:    return .triceps
        case .forearms:   return .forearms
        case .lats:       return .lats
        case .lowerBack:  return .lowerBack
        case .glutes:     return .glutes
        case .hamstrings: return .hamstrings
        case .calves:     return .calves
        }
    }

    func path(in rect: CGRect) -> Path {
        scaled(rect: rect) { p in
            switch self {
            case .traps:
                // 僧帽筋上部(肩から首にかけての菱形)
                p.move(to: CGPoint(x: 100, y: 70))
                p.addLine(to: CGPoint(x: 70, y: 84))
                p.addLine(to: CGPoint(x: 100, y: 110))
                p.addLine(to: CGPoint(x: 130, y: 84))
                p.closeSubpath()
            case .deltoids:
                p.addEllipse(in: CGRect(x: 44, y: 78, width: 24, height: 24))
                p.addEllipse(in: CGRect(x: 132, y: 78, width: 24, height: 24))
            case .triceps:
                p.addEllipse(in: CGRect(x: 36, y: 105, width: 22, height: 50))
                p.addEllipse(in: CGRect(x: 142, y: 105, width: 22, height: 50))
            case .forearms:
                p.addEllipse(in: CGRect(x: 30, y: 160, width: 22, height: 70))
                p.addEllipse(in: CGRect(x: 148, y: 160, width: 22, height: 70))
            case .lats:
                // 広背筋(両翼)
                p.move(to: CGPoint(x: 64, y: 110))
                p.addLine(to: CGPoint(x: 96, y: 130))
                p.addLine(to: CGPoint(x: 96, y: 180))
                p.addLine(to: CGPoint(x: 70, y: 165))
                p.closeSubpath()
                p.move(to: CGPoint(x: 136, y: 110))
                p.addLine(to: CGPoint(x: 104, y: 130))
                p.addLine(to: CGPoint(x: 104, y: 180))
                p.addLine(to: CGPoint(x: 130, y: 165))
                p.closeSubpath()
            case .lowerBack:
                // 腰背部(腰の中央)
                p.addRoundedRect(
                    in: CGRect(x: 82, y: 178, width: 36, height: 24),
                    cornerSize: CGSize(width: 4, height: 4)
                )
            case .glutes:
                // 臀筋(左右)
                p.addEllipse(in: CGRect(x: 66, y: 200, width: 32, height: 30))
                p.addEllipse(in: CGRect(x: 102, y: 200, width: 32, height: 30))
            case .hamstrings:
                // ハムストリング(左右、太もも裏)
                p.addEllipse(in: CGRect(x: 68, y: 232, width: 28, height: 75))
                p.addEllipse(in: CGRect(x: 104, y: 232, width: 28, height: 75))
            case .calves:
                // ふくらはぎ(左右、下腿)
                p.addEllipse(in: CGRect(x: 70, y: 318, width: 22, height: 70))
                p.addEllipse(in: CGRect(x: 108, y: 318, width: 22, height: 70))
            }
        }
    }
}

// MARK: - Path scaling helper

/// 設計時座標系(200×420)で書いた Path を、与えられた rect に等比で fit させる。
/// SwiftUI Shape の path(in:) では rect.size が描画領域なので、
/// その内側で aspect-fit のスケール変換 + センタリングを掛ける。
fileprivate func scaled(rect: CGRect, build: (inout Path) -> Void) -> Path {
    var raw = Path()
    build(&raw)

    let scale = min(rect.width / BodyLayout.designWidth,
                    rect.height / BodyLayout.designHeight)
    let scaledSize = CGSize(width: BodyLayout.designWidth * scale,
                            height: BodyLayout.designHeight * scale)
    let dx = rect.minX + (rect.width - scaledSize.width) / 2
    let dy = rect.minY + (rect.height - scaledSize.height) / 2

    let transform = CGAffineTransform(translationX: dx, y: dy)
        .scaledBy(x: scale, y: scale)
    return raw.applying(transform)
}
