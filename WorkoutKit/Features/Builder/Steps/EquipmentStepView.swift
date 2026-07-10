// MARK: - EquipmentStepView
// Builder Step 3: 器具(Equipment)。CLAUDE.md §1.1 F-01。
// 複数選択。bodyweight だけ選んでも生成可能。

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            if !isSelected {
                #if canImport(UIKit)
                UISelectionFeedbackGenerator().selectionChanged()
                #endif
            }
            onTap()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(isSelected ? AppColor.accent : .secondary)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                Text(titleKey)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColor.accent)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(isSelected ? AppColor.accent.opacity(0.12) : AppColor.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(isSelected ? AppColor.accent : Color.clear, lineWidth: 2)
            )
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("equipment.\(equipment.rawValue)")
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
