// MARK: - BodyDiagramView (v2 anatomical)
// Builder F-01 部位選択を、解剖学イラスト風の人体図上で行う。
//
// 構成:
// - 背景: workout-cool 由来 (MIT) の前面+背面シルエット SVG (gray)。
// - 選択時: 各筋肉の SVG ハイライト (orange) を base の上に重ねる。
// - タップ判定: BodyHitZones の bounding box(viewBox 535×462)を
//   実際の表示サイズへスケールして配置。

import SwiftUI

struct BodyDiagramView: View {
    @Binding var selected: Set<Muscle>

    private static let viewBoxAspect: CGFloat =
        BodyHitZones.viewBox.width / BodyHitZones.viewBox.height

    var body: some View {
        VStack(spacing: 12) {
            diagram
                .aspectRatio(Self.viewBoxAspect, contentMode: .fit)
                .frame(maxWidth: 520)

            quickActions
        }
    }

    // MARK: - Diagram stack

    private var diagram: some View {
        ZStack {
            // 背景: シルエット
            Image("Body/body-base")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(silhouetteColor)
                .scaledToFit()

            // 選択中ハイライト(全身選択時はすべての筋肉を highlight)
            ForEach(highlightMuscles, id: \.self) { muscle in
                if let asset = highlightAssetName(for: muscle) {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .transition(.opacity)
                }
            }

            // タップ判定オーバーレイ
            GeometryReader { geo in
                hitZoneLayer(in: geo.size)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("a11y.builder.muscle.diagram.label"))
    }

    /// 面積大 → 小 の順に並べて重ねるので、小さい領域が手前に来る。
    /// ZStack はソース順に「先=下、後=上」になるため、
    /// orderedFromLargestToSmallest はそのまま z-order として使える。
    private func hitZoneLayer(in containerSize: CGSize) -> some View {
        let scaleX = containerSize.width / BodyHitZones.viewBox.width
        let scaleY = containerSize.height / BodyHitZones.viewBox.height
        return ZStack(alignment: .topLeading) {
            ForEach(BodyHitZones.orderedFromLargestToSmallest, id: \.self) { muscle in
                if let zone = BodyHitZones.zones[muscle] {
                    let scaled = CGRect(
                        x: zone.minX * scaleX,
                        y: zone.minY * scaleY,
                        width: zone.width * scaleX,
                        height: zone.height * scaleY
                    )
                    hitZone(for: muscle)
                        .frame(width: scaled.width, height: scaled.height)
                        .offset(x: scaled.minX, y: scaled.minY)
                }
            }
        }
    }

    private func hitZone(for muscle: Muscle) -> some View {
        let isSelected = selected.contains(muscle) || selected.contains(.fullBody)
        return Color.clear
            .contentShape(Rectangle())
            .onTapGesture { toggle(muscle) }
            .accessibilityElement()
            .accessibilityLabel(Text(MuscleLocalization.titleKey(for: muscle)))
            .accessibilityHint(Text("a11y.builder.muscle.toggle.hint"))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Highlight selection

    /// 表示するハイライト SVG を選ぶ。fullBody が選ばれているときは
    /// アセットがある全部を表示する(視覚的に「全部光る」)。
    private var highlightMuscles: [Muscle] {
        if selected.contains(.fullBody) {
            return BodyHitZones.zones.keys.sorted(by: muscleOrder)
        }
        return Array(selected).sorted(by: muscleOrder)
    }

    private func muscleOrder(_ a: Muscle, _ b: Muscle) -> Bool {
        a.rawValue < b.rawValue
    }

    /// 各筋肉に対応する Asset Catalog 名。fullBody は固有 SVG を持たず、
    /// 上の `highlightMuscles` 経由で全部の SVG を重ねて表現する。
    private func highlightAssetName(for muscle: Muscle) -> String? {
        guard muscle != .fullBody else { return nil }
        return "Body/body-\(muscle.rawValue)"
    }

    /// 背景シルエットの色。Light/Dark 両対応。
    private var silhouetteColor: Color {
        Color.gray.opacity(0.45)
    }

    // MARK: - Quick actions

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
        if selected.contains(.fullBody) {
            selected.remove(.fullBody)
        }
        if selected.contains(muscle) {
            selected.remove(muscle)
        } else {
            selected.insert(muscle)
        }
    }

    /// 「全身」トグル。既に部位を選んでいるユーザーが全身を追加で選んだとき、
    /// 既存選択を破壊しないよう union 動作にする(他部位は残したまま fullBody を追加)。
    /// 解除時は fullBody だけを外し、他部位はそのまま残す。
    private func toggleFullBody() {
        if selected.contains(.fullBody) {
            selected.remove(.fullBody)
        } else {
            selected.insert(.fullBody)
        }
    }
}

// MARK: - Localization helper

/// MuscleStepView の旧 chip と共有する文字列キー解決。
/// LocalizedStringKey は文字列補間を引数化するので、動的キーは switch で書く。
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

#Preview("Body Diagram v2") {
    @Previewable @State var selected: Set<Muscle> = [.chest, .quadriceps]
    return BodyDiagramView(selected: $selected)
        .padding()
}
