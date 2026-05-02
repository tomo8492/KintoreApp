// MARK: - MuscleStepView
// Builder Step 2: 部位(Muscle)。CLAUDE.md §1.1 F-01。
// 複数選択。Muscle.Group(upperBody/core/lowerBody/fullBody)で見出し分け。

import SwiftUI

struct MuscleStepView: View {
    @Bindable var store: BuilderStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("builder.step.muscle.prompt")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

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
            .padding(.vertical)
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
                Text(titleKey)
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
        .accessibilityLabel(Text(titleKey))
        .accessibilityHint(Text("a11y.builder.muscle.toggle.hint"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// LocalizedStringKey は文字列補間を format 引数化するため、
    /// 動的キー(rawValue ごとに別キー)が必要なケースは switch で静的に書き分ける。
    private var titleKey: LocalizedStringKey {
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

#Preview {
    MuscleStepView(store: BuilderStore())
}
