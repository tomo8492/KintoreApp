// MARK: - FigureSceneDriver
// SCNScene + camera + lighting + figure を所有し、SceneView の
// `SCNSceneRendererDelegate` として毎フレーム pose を更新する。
//
// MainActor 規約(CLAUDE.md §-1.6):
//   このクラスは SwiftUI からは @State 越しに保持されるが、SceneKit の
//   render queue から `renderer(_:updateAtTime:)` が呼ばれる。SCNNode の
//   transform 書き換えは SceneKit が内部で同期するためスレッド安全。
//   Swift Concurrency 上は **non-isolated** にしておく(@MainActor を付けない)。

import Foundation
import SceneKit
import UIKit

final class FigureSceneDriver: NSObject, SCNSceneRendererDelegate {

    let scene: SCNScene
    let cameraNode: SCNNode
    let kind: ExerciseAnimationKind

    /// 静止モード(Reduce Motion)。true の間は phase 0.5 で固定。
    var isPaused: Bool = false {
        didSet {
            if isPaused {
                figure.apply(pose: kind.pose(phase: 0.5))
            }
        }
    }

    private let figure: HumanoidSceneFigure
    private var startTime: TimeInterval = 0
    private let cycleDuration: TimeInterval

    init(kind: ExerciseAnimationKind) {
        self.kind = kind
        self.cycleDuration = max(kind.cycleDuration, 0.001)

        scene = SCNScene()
        scene.background.contents = UIColor.clear

        // ----- Figure
        // 図形の中心(pose 正規化 y=0.5)が world y=0 になる投影だが、ポーズの
        // 多くは下半身まで含むので「フレーム上の重心」は y<0 に偏る。
        // そこで figureRoot を少し持ち上げて、視覚的に中央に乗せる。
        figure = HumanoidSceneFigure(kind: kind)
        figure.figureRoot.simdPosition = simd_float3(0, 0.5, 0)
        scene.rootNode.addChildNode(figure.figureRoot)

        // ----- Camera
        // 3/4 view: 体の正面〜側面の中間に配置すると「2D 平面」が立体に見える。
        let cam = SCNCamera()
        cam.fieldOfView = 38
        cam.zNear = 0.1
        cam.zFar = 30
        cam.wantsHDR = false
        let camNode = SCNNode()
        camNode.camera = cam
        // 種目によって正面寄り/側面寄りを少し変える。
        let camPos = Self.cameraPosition(for: kind)
        camNode.simdPosition = camPos
        // 図形の中心 (0, 0, 0) を見る。
        camNode.simdLook(at: simd_float3(0, 0, 0), up: simd_float3(0, 1, 0), localFront: simd_float3(0, 0, -1))
        cameraNode = camNode
        scene.rootNode.addChildNode(camNode)

        // ----- Lighting
        // Key (directional), fill (omni), ambient.
        let key = SCNLight()
        key.type = .directional
        key.intensity = 900
        key.color = UIColor.white
        key.castsShadow = true
        key.shadowMode = .deferred
        key.shadowSampleCount = 8
        key.shadowRadius = 4
        key.shadowColor = UIColor(white: 0, alpha: 0.45)
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.simdPosition = simd_float3(2, 4, 3)
        keyNode.simdLook(at: simd_float3(0, 0, 0), up: simd_float3(0, 1, 0), localFront: simd_float3(0, 0, -1))
        scene.rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .omni
        fill.intensity = 250
        fill.color = UIColor(red: 1.0, green: 0.92, blue: 0.85, alpha: 1.0)
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.simdPosition = simd_float3(-2, 1.5, 2)
        scene.rootNode.addChildNode(fillNode)

        let amb = SCNLight()
        amb.type = .ambient
        amb.intensity = 350
        amb.color = UIColor(white: 1.0, alpha: 1.0)
        let ambNode = SCNNode()
        ambNode.light = amb
        scene.rootNode.addChildNode(ambNode)

        // ----- Ground (受け影用の薄い色つきプレーン)
        // pose 正規化 y=0.95 が世界 y = (0.5-0.95)*2.4 = -1.08 付近に来るので、
        // それより少し下に床を敷いてフィギュアの足元の影を受ける。
        let groundPlane = SCNPlane(width: 12, height: 12)
        let groundMat = SCNMaterial()
        groundMat.lightingModel = .physicallyBased
        groundMat.diffuse.contents = UIColor(white: 0.97, alpha: 1.0)
        groundMat.metalness.contents = 0.0
        groundMat.roughness.contents = 0.95
        groundPlane.firstMaterial = groundMat
        let groundNode = SCNNode(geometry: groundPlane)
        groundNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        groundNode.simdPosition = simd_float3(0, -1.12, 0)
        scene.rootNode.addChildNode(groundNode)

        super.init()

        // 初期ポーズを 1 度反映(SceneView がまだフレームを回す前のチラつき防止)。
        figure.apply(pose: kind.pose(phase: 0.5))
    }

    // MARK: - SCNSceneRendererDelegate

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard !isPaused else { return }
        if startTime == 0 { startTime = time }
        let elapsed = time - startTime
        let normalized = elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
        figure.apply(pose: kind.pose(phase: CGFloat(normalized)))
    }

    // MARK: - Testing affordance

    /// 任意の phase でポーズを 1 度反映する。スナップショットテスト用。
    /// 呼び出し後 `isPaused = true` でアニメ進行を止めてレンダリングする想定。
    func applyPose(at phase: CGFloat) {
        figure.apply(pose: kind.pose(phase: phase))
    }

    // MARK: - Helpers

    /// 種目に応じたカメラ位置(world)。figureRoot を y=+0.5 に置いている前提。
    /// - 横向き種目(pushup/plank/lunge): 横やや前から
    /// - 正面向き種目(squat/burpee): 正面少し横から
    private static func cameraPosition(for kind: ExerciseAnimationKind) -> simd_float3 {
        switch kind {
        case .pushup:
            // pushup は地面近くで横長になるので、低めから見て立体感を強調。
            return simd_float3(0.3, 0.05, 3.6)
        case .plank:
            return simd_float3(0.3, 0.15, 3.6)
        case .lunge:
            return simd_float3(0.6, 0.4, 4.0)
        case .squat, .burpee:
            // 正面種目は視点を少し横にずらして 3/4 view にする。
            return simd_float3(1.2, 0.6, 3.8)
        }
    }
}
