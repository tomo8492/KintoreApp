// MARK: - TimeStepView
// Builder Step 4: 時間 + warmup/cooldown トグル。CLAUDE.md §1.1 F-01b。
// 時間は Foundation Locks に従い 30 / 45 / 60 / 90 分の4択。

import SwiftUI

struct TimeStepView: View {
    @Bindable var store: BuilderStore

    /// CLAUDE.md §-1 / WorkoutGenerator.swift で前提にしている候補。
    private let timeOptions: [Int] = [30, 45, 60, 90]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("builder.step.time.prompt")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                timePicker
                togglesSection
            }
            .padding(.vertical)
        }
    }

    // MARK: - Subviews

    private var timePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("builder.step.time.section.duration")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 8) {
                ForEach(timeOptions, id: \.self) { minutes in
                    timeChip(minutes: minutes)
                }
            }
            .padding(.horizontal)
        }
    }

    private func timeChip(minutes: Int) -> some View {
        let isSelected = store.input.minutesAvailable == minutes
        return Button {
            store.input.minutesAvailable = minutes
        } label: {
            VStack(spacing: 2) {
                Text("\(minutes)")
                    .font(.title3.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("builder.step.time.unit.minutes")
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("time.\(minutes)")
        .accessibilityLabel(Text("a11y.builder.time.chip \(minutes)"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("builder.step.time.section.options")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                Toggle(isOn: $store.input.includeWarmup) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("builder.step.time.warmup.title").font(.body)
                        Text("builder.step.time.warmup.description")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

                Divider().padding(.leading)

                Toggle(isOn: $store.input.includeCooldown) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("builder.step.time.cooldown.title").font(.body)
                        Text("builder.step.time.cooldown.description")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.08))
            )
            .padding(.horizontal)
        }
    }
}

#Preview {
    TimeStepView(store: BuilderStore())
}
