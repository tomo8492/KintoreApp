// MARK: - MuscleStepView
// Builder Step 2: 部位(Muscle)。CLAUDE.md §1.1 F-01。
// デフォルトは BodyDiagramView(視覚ピッカー)。互換のため
// 旧テキストチップ UI も折りたたみで併設し、ユーザーが選択できる。

import SwiftUI

struct MuscleStepView: View {
    @Bindable var store: BuilderStore

    /// 視覚版(diagram)/ レガシー(chip)の表示モード。
    @State private var pickerMode: PickerMode = .diagram

    enum PickerMode: String, CaseIterable, Identifiable {
        case diagram
        case list

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .diagram: return "builder.muscle.picker.mode.diagram"
            case .list:    return "builder.muscle.picker.mode.list"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("builder.step.muscle.prompt")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Picker(selection: $pickerMode) {
                    ForEach(PickerMode.allCases) { mode in
                        Text(mode.titleKey).tag(mode)
                    }
                } label: {
                    Text("builder.muscle.picker.mode.label")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch pickerMode {
                case .diagram:
                    BodyDiagramView(selected: $store.input.muscles)
                case .list:
                    listMode
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Legacy list mode

    private var listMode: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Muscle.Group.allCases, id: \.self) { group in
                MuscleGroupSection(
                    group: group,
                    muscles: musclesIn(group),
                    selected: store.input.muscles
                ) { muscle in
                    toggle(muscle)
                }
            }
        }
    }

    // MARK: - Helpers

    private func musclesIn(_ group: Muscle.Group) -> [Muscle] {
        Muscle.allCases.filter { $0.group == group }
    }

    private func toggle(_ muscle: Muscle) {
        if store.input.muscles.contains(muscle) {
            store.input.muscles.remove(muscle)
        } else {
            store.input.muscles.insert(muscle)
        }
    }
}

private struct MuscleGroupSection: View {
    let group: Muscle.Group
    let muscles: [Muscle]
    let selected: Set<Muscle>
    let onTap: (Muscle) -> Void

    private let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(groupTitleKey)
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(muscles, id: \.self) { muscle in
                    MuscleChip(
                        muscle: muscle,
                        isSelected: selected.contains(muscle)
                    ) {
                        onTap(muscle)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var groupTitleKey: LocalizedStringKey {
        switch group {
        case .upperBody: return "muscle.group.upperBody.title"
        case .core:      return "muscle.group.core.title"
        case .lowerBody: return "muscle.group.lowerBody.title"
        case .fullBody:  return "muscle.group.fullBody.title"
        }
    }
}

private struct MuscleChip: View {
    let muscle: Muscle
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(MuscleLocalization.titleKey(for: muscle))
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(MuscleLocalization.titleKey(for: muscle)))
        .accessibilityHint(Text("a11y.builder.muscle.toggle.hint"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    MuscleStepView(store: BuilderStore())
}
