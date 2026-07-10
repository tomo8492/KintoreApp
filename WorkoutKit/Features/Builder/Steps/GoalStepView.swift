// MARK: - GoalStepView
// Builder Step 1: 目的(Goal)。CLAUDE.md §1.1 F-01。
// 選択は単一(ラジオ相当)。タップで `store.input.goal` を更新する。

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct GoalStepView: View {
    @Bindable var store: BuilderStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("builder.step.goal.prompt")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ForEach(Goal.allCases, id: \.self) { goal in
                    GoalRow(
                        goal: goal,
                        isSelected: store.input.goal == goal
                    ) {
                        store.input.goal = goal
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

private struct GoalRow: View {
    let goal: Goal
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
            HStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundStyle(isSelected ? AppColor.accent : .secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(titleKey)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(descriptionKey)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColor.accent)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(isSelected ? AppColor.accent.opacity(0.12) : AppColor.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(isSelected ? AppColor.accent : Color.clear, lineWidth: 2)
            )
            .padding(.horizontal)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("goal.\(goal.rawValue)")
        .accessibilityLabel(Text(titleKey))
        .accessibilityHint(Text(descriptionKey))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var titleKey: LocalizedStringKey {
        switch goal {
        case .hypertrophy: return "goal.hypertrophy.title"
        case .fatLoss:     return "goal.fat-loss.title"
        case .endurance:   return "goal.endurance.title"
        case .flexibility: return "goal.flexibility.title"
        case .cardio:      return "goal.cardio.title"
        }
    }

    private var descriptionKey: LocalizedStringKey {
        switch goal {
        case .hypertrophy: return "goal.hypertrophy.description"
        case .fatLoss:     return "goal.fat-loss.description"
        case .endurance:   return "goal.endurance.description"
        case .flexibility: return "goal.flexibility.description"
        case .cardio:      return "goal.cardio.description"
        }
    }

    private var iconName: String {
        switch goal {
        case .hypertrophy: return "figure.strengthtraining.traditional"
        case .fatLoss:     return "flame"
        case .endurance:   return "stopwatch"
        case .flexibility: return "figure.flexibility"
        case .cardio:      return "heart"
        }
    }
}

#Preview {
    GoalStepView(store: BuilderStore())
}
