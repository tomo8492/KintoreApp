// MARK: - EquipmentStepView
// Builder Step 3: 器具(Equipment)。CLAUDE.md §1.1 F-01。
// 複数選択。bodyweight だけ選んでも生成可能。

import SwiftUI

struct EquipmentStepView: View {
    @Bindable var store: BuilderStore

    private let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("builder.step.equipment.prompt")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        EquipmentChip(
                            equipment: equipment,
                            isSelected: store.input.equipment.contains(equipment)
                        ) {
                            toggle(equipment)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private func toggle(_ equipment: Equipment) {
        if store.input.equipment.contains(equipment) {
            store.input.equipment.remove(equipment)
        } else {
            store.input.equipment.insert(equipment)
        }
    }
}

private struct EquipmentChip: View {
    let equipment: Equipment
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                    .accessibilityHidden(true)
                Text(titleKey)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(titleKey))
        .accessibilityHint(Text("a11y.builder.equipment.toggle.hint"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// LocalizedStringKey に文字列補間を渡すと format 引数化されてしまうため、
    /// 動的キーは switch で静的に書き分ける。
    private var titleKey: LocalizedStringKey {
        switch equipment {
        case .bodyweight: return "equipment.bodyweight.title"
        case .dumbbell:   return "equipment.dumbbell.title"
        case .barbell:    return "equipment.barbell.title"
        case .kettlebell: return "equipment.kettlebell.title"
        case .machine:    return "equipment.machine.title"
        case .cable:      return "equipment.cable.title"
        case .band:       return "equipment.band.title"
        case .pullupBar:  return "equipment.pullupBar.title"
        case .bench:      return "equipment.bench.title"
        case .trx:        return "equipment.trx.title"
        case .foamRoller: return "equipment.foamRoller.title"
        case .yogaMat:    return "equipment.yogaMat.title"
        }
    }

    /// SF Symbols は iOS 17 で確定して存在するもののみ使う。
    /// 専用シンボルが見つからないものは抽象的な代替を当てる。
    private var iconName: String {
        switch equipment {
        case .bodyweight: return "figure.strengthtraining.functional"
        case .dumbbell:   return "dumbbell"
        case .barbell:    return "dumbbell.fill"
        case .kettlebell: return "scalemass"
        case .machine:    return "gearshape.2"
        case .cable:      return "link"
        case .band:       return "waveform.path"
        // figure.pull.up は iOS 26 で消えていてレンダーされないため、
        // 安全な代替に置換する(同種の strength training グリフ)。
        case .pullupBar:  return "figure.strengthtraining.functional"
        case .bench:      return "rectangle.fill"
        case .trx:        return "figure.flexibility"
        case .foamRoller: return "capsule"
        case .yogaMat:    return "rectangle.portrait"
        }
    }
}

#Preview {
    EquipmentStepView(store: BuilderStore())
}
