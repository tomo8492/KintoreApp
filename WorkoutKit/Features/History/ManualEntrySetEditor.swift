// MARK: - ManualEntrySetEditor
// CLAUDE.md §1.1 F-04 / §-1.4 (内部単位 kg) / §11.4 準拠。
// ManualEntryView から切り出した「種目ごとの 1 セクション」と「1 セット行」のサブビュー。
//
// 重量入力は kg のみ。ユーザー設定で lb 表示にするのは v1.1+ で別途追加する想定。
// (現状 Settings 画面が未実装で WeightUnitPreference を渡す経路がないため、
//  保存値 = 内部単位 kg で受ける = §-1.4 規約と整合させる。)

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

    private var weightField: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("manual-entry.weight-kg")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField(
                    "manual-entry.weight-kg",
                    value: Binding(
                        get: { set.weightKg },
                        set: { newValue in
                            onChange { $0.weightKg = max(0, newValue) }
                        }
                    ),
                    format: .number.precision(.fractionLength(0...2))
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .textFieldStyle(.roundedBorder)

                Stepper(
                    "manual-entry.weight-kg",
                    value: Binding(
                        get: { set.weightKg },
                        set: { newValue in
                            onChange { $0.weightKg = max(0, newValue) }
                        }
                    ),
                    in: 0...999.5,
                    step: 2.5
                )
                .labelsHidden()
            }
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
