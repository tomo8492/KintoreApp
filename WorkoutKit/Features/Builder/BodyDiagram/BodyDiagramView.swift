// MARK: - BodyDiagramView
// Builder F-01 部位ステップの視覚版ピッカー。
// 人体図(前面/後面)上で筋肉領域をタップして選択/解除する。
//
// 仕様:
// - Front/Back セグメント切替。
// - 各筋肉領域は Shape として描画し、選択時は accent カラーでハイライト。
// - 「全身」など複合は別ボタン(下のクイック選択行)で提供。
// - 選択状態は親 View が保持する Set<Muscle> に Binding で書き戻す。

import SwiftUI

struct BodyDiagramView: View {
    @Binding var selected: Set<Muscle>

    @State private var side: BodySide = .front

    private let designAspect: CGFloat = BodyLayout.designWidth / BodyLayout.designHeight

    var body: some View {
        VStack(spacing: 12) {
            sidePicker

            diagram
                .aspectRatio(designAspect, contentMode: .fit)
                .frame(maxWidth: 320)
                .padding(.horizontal)

            quickActions
        }
    }

    // MARK: - Subviews

    private var sidePicker: some View {
        Picker(selection: $side) {
            ForEach(BodySide.allCases) { s in
                Text(s.titleKey).tag(s)
            }
        } label: {
            Text("builder.muscle.diagram.side.label")
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private var diagram: some View {
        ZStack {
            // 背景シルエット
            BodySilhouetteShape()
                .fill(Color.gray.opacity(0.18))
                .overlay(
                    BodySilhouetteShape()
                        .stroke(Color.gray.opacity(0.45), lineWidth: 1)
                )

            // 各筋肉領域
            switch side {
            case .front:
                ForEach(Array(FrontMuscleRegion.allCases.enumerated()), id: \.offset) { _, region in
                    muscleLayer(
                        muscle: region.muscle,
                        path: { region.path(in: $0) }
                    )
                }
            case .back:
                ForEach(Array(BackMuscleRegion.allCases.enumerated()), id: \.offset) { _, region in
                    muscleLayer(
                        muscle: region.muscle,
                        path: { region.path(in: $0) }
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("a11y.builder.muscle.diagram.label"))
    }

    private func muscleLayer(muscle: Muscle, path: @escaping (CGRect) -> Path) -> some View {
        let isSelected = selected.contains(muscle) || selected.contains(.fullBody)
        return MuscleRegionShape(pathBuilder: path)
            .fill(isSelected ? Color.accentColor.opacity(0.85)
                              : Color.gray.opacity(0.45))
            .overlay(
                MuscleRegionShape(pathBuilder: path)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.7),
                            lineWidth: 1)
            )
            .contentShape(MuscleRegionShape(pathBuilder: path))
            .onTapGesture { toggle(muscle) }
            .accessibilityElement()
            .accessibilityLabel(Text(MuscleLocalization.titleKey(for: muscle)))
            .accessibilityHint(Text("a11y.builder.muscle.toggle.hint"))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var quickActions: some View {
        HStack(spacing: 8) {
            Button {
                toggleFullBody()
            } label: {
                Label {
                    Text("muscle.fullBody.title")
                } icon: {
                    Image(systemName: "figure.arms.open")
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        selected.contains(.fullBody)
                            ? Color.accentColor
                            : Color.gray.opacity(0.18)
                    )
                )
                .foregroundStyle(selected.contains(.fullBody) ? Color.white : Color.primary)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected.contains(.fullBody)
                                    ? [.isButton, .isSelected] : .isButton)

            if !selected.isEmpty {
                Button {
                    selected.removeAll()
                } label: {
                    Label {
                        Text("builder.muscle.diagram.clear")
                    } icon: {
                        Image(systemName: "xmark.circle")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.gray.opacity(0.12)))
                    .foregroundStyle(Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Selection logic

    private func toggle(_ muscle: Muscle) {
        // 全身選択中に個別をタップしたら、全身を解除して個別を入れる(直感的UX)。
        if selected.contains(.fullBody) {
            selected.remove(.fullBody)
        }
        if selected.contains(muscle) {
            selected.remove(muscle)
        } else {
            selected.insert(muscle)
        }
    }

    private func toggleFullBody() {
        if selected.contains(.fullBody) {
            selected.remove(.fullBody)
        } else {
            selected = [.fullBody]
        }
    }
}

// MARK: - MuscleRegionShape

/// `Shape` プロトコルに乗せるための薄いラッパ。
/// `path(in:)` を毎フレーム呼ぶので、`pathBuilder` 内で
/// 巨大なオブジェクトを生成しないこと。
private struct MuscleRegionShape: Shape {
    let pathBuilder: (CGRect) -> Path

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

// MARK: - Localization mapping

/// MuscleStepView の旧 chip と同等の static 文字列キー解決を共有するヘルパ。
/// LocalizedStringKey は文字列補間を引数化するので、
/// 動的キー(rawValue ごと)はここで switch で書き分ける。
enum MuscleLocalization {
    static func titleKey(for muscle: Muscle) -> LocalizedStringKey {
        switch muscle {
        case .chest:      return "muscle.chest.title"
        case .lats:       return "muscle.lats.title"
        case .traps:      return "muscle.traps.title"
        case .deltoids:   return "muscle.deltoids.title"
        case .biceps:     return "muscle.biceps.title"
        case .triceps:    return "muscle.triceps.title"
        case .forearms:   return "muscle.forearms.title"
        case .abs:        return "muscle.abs.title"
        case .obliques:   return "muscle.obliques.title"
        case .lowerBack:  return "muscle.lowerBack.title"
        case .quadriceps: return "muscle.quadriceps.title"
        case .hamstrings: return "muscle.hamstrings.title"
        case .glutes:     return "muscle.glutes.title"
        case .calves:     return "muscle.calves.title"
        case .fullBody:   return "muscle.fullBody.title"
        }
    }
}

#Preview("Body Diagram") {
    @Previewable @State var selected: Set<Muscle> = [.chest, .biceps]
    return BodyDiagramView(selected: $selected)
        .padding()
}
