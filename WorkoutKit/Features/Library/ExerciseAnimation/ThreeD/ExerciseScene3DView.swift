// MARK: - ExerciseScene3DView
// SwiftUI から FigureSceneDriver を持ち上げてレンダリングする View。
// SwiftUI 標準の `SceneView` を使うため UIViewRepresentable は不要。
//
// reduceMotion ON 時は driver.isPaused=true で phase=0.5 固定にする。

import SwiftUI
import SceneKit

struct ExerciseScene3DView: View {
    let kind: ExerciseAnimationKind

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// State として持たないと SwiftUI の View 値型再生成で driver が毎回作り直され、
    /// 連続再生にならないため `@State` で保持する。
    @State private var driver: FigureSceneDriver

    init(kind: ExerciseAnimationKind) {
        self.kind = kind
        _driver = State(initialValue: FigureSceneDriver(kind: kind))
    }

    var body: some View {
        SceneView(
            scene: driver.scene,
            pointOfView: driver.cameraNode,
            options: reduceMotion ? [] : [.rendersContinuously],
            antialiasingMode: .multisampling4X,
            delegate: driver
        )
        .background(Color.clear)
        .onAppear {
            driver.isPaused = reduceMotion
        }
        .onChange(of: reduceMotion) { _, newValue in
            driver.isPaused = newValue
        }
    }
}

#if DEBUG
#Preview("3D push-up") {
    ExerciseScene3DView(kind: .pushup)
        .frame(height: 320)
        .padding()
}

#Preview("3D squat") {
    ExerciseScene3DView(kind: .squat)
        .frame(height: 320)
        .padding()
}
#endif
