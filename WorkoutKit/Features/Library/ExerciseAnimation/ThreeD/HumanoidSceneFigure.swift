// MARK: - HumanoidSceneFigure
// 3D プロトタイプ: SceneKit プリミティブ(SCNSphere/SCNCylinder)で組み立てた
// 簡易ヒューマノイド。各 phase の StickFigurePose(既存 2D 表現)を入力に取り、
// 関節球と骨シリンダーの transform を更新する。
//
// 設計方針:
//   - 2D ポーズ math(StickFigurePose, *Animation.pose(phase:))は既存のまま再利用。
//   - 正規化座標 (0...1) のジョイント位置を「シーン空間 (x: 中心, y: 上向き, z: 0)」に投影。
//   - 全関節 z=0 平面の planar フィギュア + 3/4 視点カメラ + 直接光 + 影 で
//     視覚的に「3D」を強く感じさせる。SCNNode 数は 30 以下で軽量。
//   - 動画 mp4 同梱は §-1 Lock により禁止だが、SceneKit 手続き生成は OK。

import Foundation
import SceneKit
import UIKit

/// 1 体分のヒューマノイド SCNNode 群。`apply(pose:)` で毎フレーム更新する。
///
/// `figureRoot` 配下に関節球と骨シリンダーが乗る。Driver からは
/// `figureRoot` をシーンに add し、`apply(pose:)` を毎フレーム呼ぶ。
final class HumanoidSceneFigure {

    /// シーンに add する figure 全体のルート。
    let figureRoot: SCNNode

    /// 関節 → 球ノードの対応(初期化時に固定セット作成)。
    private var jointNodes: [StickFigurePose.Joint: SCNNode] = [:]

    /// 骨 (from→to) → シリンダーノードの対応。
    private var boneNodes: [BoneKey: SCNNode] = [:]

    /// 頭ノード(任意。pose.head が存在する種目のみ)。
    private let headNode: SCNNode

    /// 描画スケール: 正規化 1.0(短辺)を world 座標 ~2.0 にマップ。
    private static let worldExtent: Float = 2.4

    /// 関節球の半径。
    private static let jointRadius: CGFloat = 0.07

    /// 骨シリンダーの半径。
    private static let boneRadius: CGFloat = 0.05

    /// 頭の半径(pose.head.radiusRatio に応じてスケール)。
    private static let headBaseRadius: CGFloat = 0.10

    init(kind: ExerciseAnimationKind) {
        figureRoot = SCNNode()
        headNode = Self.makeHeadNode()
        figureRoot.addChildNode(headNode)
        headNode.isHidden = true

        // ポーズ集合を 1 度評価して、登場するジョイント / ボーンの全種類を抽出する。
        // *Animation.pose(phase:) は phase によらず同じキーセットを返す前提だが、
        // 安全側に取って 0.0 / 0.5 / 1.0 を集合に入れる。
        let probePoses = [0.0, 0.5, 1.0].map { kind.pose(phase: $0) }
        var jointKeys = Set<StickFigurePose.Joint>()
        var boneKeys = Set<BoneKey>()
        for p in probePoses {
            for j in p.joints.keys { jointKeys.insert(j) }
            for b in p.bones { boneKeys.insert(BoneKey(b)) }
        }

        // 関節球。
        for j in jointKeys {
            let n = Self.makeJointNode()
            jointNodes[j] = n
            figureRoot.addChildNode(n)
        }

        // 骨シリンダー。標準の SCNCylinder は y 軸方向、高さ 1。毎フレーム
        // 中点に移動 + 方向に向け + Y スケールで長さを調整する。
        for k in boneKeys {
            let n = Self.makeBoneNode()
            boneNodes[k] = n
            figureRoot.addChildNode(n)
        }
    }

    // MARK: - Pose application

    /// Pose を投影してシーンに反映する。
    func apply(pose: StickFigurePose) {
        // 関節球。
        for (joint, node) in jointNodes {
            if let p = pose.joints[joint] {
                node.simdPosition = Self.project(p)
                node.isHidden = false
            } else {
                node.isHidden = true
            }
        }

        // 骨。
        // 表示すべき骨集合を pose から拾い、それ以外は隠す。
        var visibleBones = Set<BoneKey>()
        for bone in pose.bones {
            let key = BoneKey(bone)
            visibleBones.insert(key)
            guard let node = boneNodes[key],
                  let a = pose.joints[bone.from],
                  let b = pose.joints[bone.to] else { continue }
            Self.placeBone(node: node, from: Self.project(a), to: Self.project(b))
            node.isHidden = false
        }
        for (key, node) in boneNodes where !visibleBones.contains(key) {
            node.isHidden = true
        }

        // 頭。
        if let head = pose.head {
            headNode.isHidden = false
            headNode.simdPosition = Self.project(head.center)
            // radiusRatio は短辺基準。world 座標換算で worldExtent の半分にスケール。
            // 視覚上の見栄えを優先し、ベース 0.10 を下限にして拡大のみ。
            let r = max(Self.headBaseRadius, CGFloat(head.radiusRatio) * CGFloat(Self.worldExtent) * 0.6)
            (headNode.geometry as? SCNSphere)?.radius = r
        } else {
            headNode.isHidden = true
        }
    }

    // MARK: - Geometry factories

    private static func makeJointNode() -> SCNNode {
        let geo = SCNSphere(radius: jointRadius)
        geo.segmentCount = 18
        geo.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.50, blue: 0.30, alpha: 1.0)
        geo.firstMaterial?.lightingModel = .physicallyBased
        geo.firstMaterial?.metalness.contents = 0.0
        geo.firstMaterial?.roughness.contents = 0.55
        return SCNNode(geometry: geo)
    }

    private static func makeBoneNode() -> SCNNode {
        let geo = SCNCylinder(radius: boneRadius, height: 1.0)
        geo.radialSegmentCount = 16
        geo.firstMaterial?.diffuse.contents = UIColor(red: 0.95, green: 0.55, blue: 0.40, alpha: 1.0)
        geo.firstMaterial?.lightingModel = .physicallyBased
        geo.firstMaterial?.metalness.contents = 0.0
        geo.firstMaterial?.roughness.contents = 0.6
        return SCNNode(geometry: geo)
    }

    private static func makeHeadNode() -> SCNNode {
        let geo = SCNSphere(radius: headBaseRadius)
        geo.segmentCount = 24
        geo.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.78, blue: 0.62, alpha: 1.0)
        geo.firstMaterial?.lightingModel = .physicallyBased
        geo.firstMaterial?.metalness.contents = 0.0
        geo.firstMaterial?.roughness.contents = 0.5
        return SCNNode(geometry: geo)
    }

    // MARK: - Projection / placement

    /// 正規化 2D 座標 (0...1) → シーン 3D 座標 (x: -worldExtent/2 ... +, y: 反転)
    /// - 原点をフィギュアの中心 (0.5, 0.5) に取り、Y 軸を上向きに反転。
    /// - Z は 0 で planar(視点の 3/4 angle で十分立体的に見える)。
    private static func project(_ p: CGPoint) -> simd_float3 {
        let x = Float(p.x - 0.5) * worldExtent
        // 2D は Y down 前提なので 3D の Y up に反転。
        let y = Float(0.5 - p.y) * worldExtent
        let z: Float = 0
        return simd_float3(x, y, z)
    }

    /// 骨シリンダーを 2 点間に配置する。
    /// - SCNCylinder 既定: 中心が原点、Y 軸沿い、長さ 1。
    /// - 中点に移動 → Y を |b-a| に scale → Y軸を方向ベクトルに回転。
    /// - 反対方向ベクトル(下向き)で `simd_quatf(from:to:)` の挙動が不安定に
    ///   なるため、明示的に dot/cross からクォータニオンを構築する。
    private static func placeBone(node: SCNNode, from a: simd_float3, to b: simd_float3) {
        let mid = (a + b) * 0.5
        let dir = b - a
        let len = simd_length(dir)
        guard len > 1e-5 else {
            node.isHidden = true
            return
        }
        node.simdPosition = mid
        node.simdScale = simd_float3(1, len, 1)

        let up = simd_float3(0, 1, 0)
        let dirN = dir / len
        let d = simd_dot(up, dirN)
        if d > 0.9999 {
            node.simdOrientation = simd_quatf(angle: 0, axis: simd_float3(1, 0, 0))
        } else if d < -0.9999 {
            // ほぼ反対向き。Z 軸まわり 180° 回転で揃える。
            node.simdOrientation = simd_quatf(angle: .pi, axis: simd_float3(0, 0, 1))
        } else {
            let axis = simd_normalize(simd_cross(up, dirN))
            let angle = acosf(d)
            node.simdOrientation = simd_quatf(angle: angle, axis: axis)
        }
    }
}

/// 2 ジョイントペアの順序非依存キー。Set/辞書で骨インスタンスを再利用する。
struct BoneKey: Hashable {
    let a: StickFigurePose.Joint
    let b: StickFigurePose.Joint

    init(_ bone: StickFigurePose.Bone) {
        // from→to を a/b に正規化(.hashValue 順は安定でないので Description で揃える)。
        let s1 = String(describing: bone.from)
        let s2 = String(describing: bone.to)
        if s1 <= s2 {
            self.a = bone.from
            self.b = bone.to
        } else {
            self.a = bone.to
            self.b = bone.from
        }
    }
}
