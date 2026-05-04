// MARK: - ManualEntrySetEditor
// CLAUDE.md §1.1 F-04 / §-1.4 (内部単位 kg) / §11.4 準拠。
// ManualEntryView から切り出した「種目ごとの 1 セクション」と「1 セット行」のサブビュー。
//
// 保存値は常に内部単位 kg(§-1.4)。Settings の `weightUnit` 設定に応じて、
// TextField / Stepper の表示値とラベルを kg / lb に切替える。
// kg ↔ lb 変換は UnitsFormatter.toKilograms / lbsPerKg 経由で行う。

import SwiftUI

// MARK: - ManualEntryExerciseSection

@MainActor
struct ManualEntryExerciseSection: View {
    let draft: ManualEntryDraft

    /// セット 1 行の内容を mutate するコールバック。
    /// `inout` を取ることで View 側のロジックを最小化する。
    let onUpdateSet: (UUID, (inout ManualEntrySetDraft) -> Void) -> Void
    let onAddSet: () -> Void
    let onRemoveSet: (UUID) -> Void
    let onRemoveExercise: () -> Void

    var body: some View {
        Section {
            ForEach(draft.sets) { set in
                ManualEntrySetRow(
                    index: (draft.sets.firstIndex(of: set) ?? 0) + 1,
                    set: set,
                    onChange: { mutate in onUpdateSet(set.id, mutate) }
                )
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        onRemoveSet(set.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Button {
                onAddSet()
            } label: {
                Label("manual-entry.add-set", systemImage: "plus")
            }
        } header: {
            HStack {
                Text(draft.displayName)
                Spacer()
                Button(role: .destructive) {
                    onRemoveExercise()
                } label: {
                    Image(systemName: "minus.circle")
                        .accessibilityLabel(Text("manual-entry.remove-exercise"))
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

// MARK: - ManualEntrySetRow

@MainActor
struct ManualEntrySetRow: View {
    let index: Int
    let set: ManualEntrySetDraft
    let onChange: ((inout ManualEntrySetDraft) -> Void) -> Void

    @State private var rpeEnabled: Bool

    @AppStorage(SettingsKey.weightUnit) private var weightUnitRaw: String = WeightUnitPreference.kilograms.rawValue
    private var weightUnit: WeightUnitPreference {
        WeightUnitPreference(rawValue: weightUnitRaw) ?? .kilograms
    }

    init(
        index: Int,
        set: ManualEntrySetDraft,
        onChange: @escaping ((inout ManualEntrySetDraft) -> Void) -> Void
    ) {
        self.index = index
        self.set = set
        self.onChange = onChange
        self._rpeEnabled = State(initialValue: set.rpe != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                indexBadge
                repsField
                weightField
            }

            HStack(spacing: 12) {
                Toggle(isOn: $rpeEnabled) {
                    Text("RPE")
                        .font(.caption.weight(.medium))
                }
                .toggleStyle(.button)
                .controlSize(.mini)
                .onChange(of: rpeEnabled) { _, newValue in
                    onChange { draft in
                        draft.rpe = newValue ? (draft.rpe ?? 8.0) : nil
                    }
                }

                if rpeEnabled {
                    rpeStepper
                } else {
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Sub fields

    private var indexBadge: some View {
        Text("\(index)")
            .font(.caption.weight(.semibold).monospacedDigit())
            .frame(width: 24, height: 24)
            .background(Color.accentColor.opacity(0.15))
            .clipShape(Circle())
    }

    private var repsField: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("manual-entry.reps")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField(
                    "manual-entry.reps",
                    value: Binding(
                        get: { set.reps },
                        set: { newValue in
                            onChange { $0.reps = max(0, newValue) }
                        }
                    ),
                    format: .number
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 56)
                .textFieldStyle(.roundedBorder)

                Stepper(
                    "manual-entry.reps",
                    value: Binding(
                        get: { set.reps },
                        set: { newValue in
                            onChange { $0.reps = max(0, newValue) }
                        }
                    ),
                    in: 0...999
                )
                .labelsHidden()
            }
        }
    }

    /// 重量入力。保存値は内部単位 kg 固定。表示・入力は Settings の単位に従う。
    /// kg 設定: 2.5 kg 刻み / lb 設定: 5 lb (≈ 2.27 kg) 刻み。
    private var weightField: some View {
        let labelKey: LocalizedStringKey = weightUnit == .pounds
            ? "manual-entry.weight-lb"
            : "manual-entry.weight-kg"

        let displayBinding = Binding<Double>(
            get: { displayedWeight(fromKg: set.weightKg) },
            set: { newDisplay in
                let kg = UnitsFormatter.toKilograms(newDisplay, from: weightUnit)
                onChange { $0.weightKg = max(0, kg) }
            }
        )

        let displayStep: Double = weightUnit == .pounds ? 5.0 : 2.5
        let displayMax: Double = weightUnit == .pounds ? 2200.0 : 999.5

        return VStack(alignment: .leading, spacing: 2) {
            Text(labelKey)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField(
                    labelKey,
                    value: displayBinding,
                    format: .number.precision(.fractionLength(0...2))
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .textFieldStyle(.roundedBorder)

                Stepper(
                    labelKey,
                    value: displayBinding,
                    in: 0...displayMax,
                    step: displayStep
                )
                .labelsHidden()
            }
        }
    }

    /// 内部 kg を Settings に応じた表示単位の値に変換する。
    private func displayedWeight(fromKg kg: Double) -> Double {
        switch weightUnit {
        case .kilograms: return kg
        case .pounds:    return kg * 2.2046226218
        }
    }

    private var rpeStepper: some View {
        let binding = Binding<Double>(
            get: { set.rpe ?? 8.0 },
            set: { newValue in
                onChange { $0.rpe = newValue }
            }
        )
        return HStack(spacing: 4) {
            Text(String(format: "%.1f", binding.wrappedValue))
                .font(.subheadline.monospacedDigit())
                .frame(width: 36, alignment: .trailing)
            Stepper(
                "RPE",
                value: binding,
                in: 6.0...10.0,
                step: 0.5
            )
            .labelsHidden()
        }
    }
}
