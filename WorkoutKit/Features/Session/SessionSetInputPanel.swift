// MARK: - SessionSetInputPanel
// 現在セットの入力 UI。CLAUDE.md §1.1 F-03 / §-1.4 準拠。
// - 重量は内部単位 kg で SessionStore に保持。表示と Stepper の刻みは
//   `@AppStorage(SettingsKey.weightUnit)` を読んで kg / lb を切り替える(§-1.4)。
// - kg 設定: 0.5 kg 刻み / lb 設定: 1 lb (≈ 0.4536 kg) 刻み。
// - reps / RPE / 休憩秒は Stepper で素早く調整。
// - "Complete Set" ボタンは store.completeCurrentSet() を呼ぶだけ。

import SwiftUI

struct SessionSetInputPanel: View {
    @Bindable var store: SessionStore
    let item: SessionPlanItem
    let exercise: Exercise?
    let onComplete: () -> Void
    let onSkip: () -> Void
    let onAbort: () -> Void

    /// Settings から読む重量単位。kg / lbs 切替に追従して再描画される。
    @AppStorage(SettingsKey.weightUnit) private var weightUnitRaw: String = WeightUnitPreference.kilograms.rawValue

    private var weightUnit: WeightUnitPreference {
        WeightUnitPreference(rawValue: weightUnitRaw) ?? .kilograms
    }

    /// Stepper の刻み(内部単位 kg)。
    /// kg 設定: 0.5 kg / lb 設定: 1 lb を kg に換算した値。
    private var weightStepKg: Double {
        switch weightUnit {
        case .kilograms: return 0.5
        case .pounds:    return UnitsFormatter.toKilograms(1.0, from: .pounds)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()

            inputRow(
                titleKey: "session.input.reps",
                value: $store.inputReps,
                step: 1,
                range: 0...100,
                display: { "\($0)" }
            )

            weightRow

            inputRow(
                titleKey: "session.input.rest",
                value: $store.inputRestSeconds,
                step: 5,
                range: 0...600,
                display: { UnitsFormatter.formatDuration(seconds: $0) }
            )

            rpeRow

            actionButtons
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.section.titleKey)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(displayName)
                .font(.title3.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            let setText = String(
                localized: "session.input.current-set",
                defaultValue: "セット %lld / %lld"
            )
            Text(String(format: setText, store.currentSetIndex + 1, item.plannedSetCount))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Generic stepper row

    private func inputRow(
        titleKey: LocalizedStringKey,
        value: Binding<Int>,
        step: Int,
        range: ClosedRange<Int>,
        display: @escaping (Int) -> String
    ) -> some View {
        HStack {
            Text(titleKey)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Text(display(value.wrappedValue))
                .font(.body.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityHidden(true)
            Stepper(value: value, in: range, step: step) {
                Text(titleKey)
            }
            .labelsHidden()
            .accessibilityValue(Text(display(value.wrappedValue)))
        }
    }

    // MARK: - Weight row(kg 設定: 0.5 kg 刻み / lb 設定: 1 lb 刻み)

    private var weightRow: some View {
        HStack {
            Text("session.input.weight")
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Text(UnitsFormatter.formatWeight(store.inputWeightKg, preference: weightUnit))
                .font(.body.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityHidden(true)
            Stepper(
                value: $store.inputWeightKg,
                in: 0...500,
                step: weightStepKg
            ) {
                Text("session.input.weight")
            }
            .labelsHidden()
            .accessibilityValue(Text(UnitsFormatter.formatWeight(store.inputWeightKg, preference: weightUnit)))
        }
    }

    // MARK: - RPE row(任意、6.0〜10.0)

    private var rpeRow: some View {
        let rpeText: String = {
            if let rpe = store.inputRpe {
                return String(format: "%.1f", rpe)
            }
            return String(localized: "session.input.rpe.none", defaultValue: "未設定")
        }()
        return HStack {
            Text("session.input.rpe")
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            if let rpe = store.inputRpe {
                Text(String(format: "%.1f", rpe))
                    .font(.body.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityHidden(true)
            } else {
                Text("session.input.rpe.none")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityHidden(true)
            }
            Stepper(
                onIncrement: { adjustRpe(by: 0.5) },
                onDecrement: { adjustRpe(by: -0.5) }
            ) {
                Text("session.input.rpe")
            }
            .labelsHidden()
            .accessibilityValue(Text(rpeText))
        }
    }

    private func adjustRpe(by delta: Double) {
        let next = (store.inputRpe ?? 7.0) + delta
        store.inputRpe = max(6.0, min(10.0, next))
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button(action: onComplete) {
                Text("session.action.complete-set")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("session.action.complete-set")
            .accessibilityLabel(Text("session.action.complete-set"))
            .accessibilityHint(Text("a11y.session.complete.hint"))
            .accessibilityAddTraits(.isButton)

            HStack(spacing: 8) {
                Button(action: onSkip) {
                    Text("session.action.skip")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("session.action.skip")
                .accessibilityLabel(Text("session.action.skip"))
                .accessibilityHint(Text("a11y.session.skip.hint"))
                .accessibilityAddTraits(.isButton)

                Button(role: .destructive, action: onAbort) {
                    Text("session.action.stop")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.10))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("session.action.stop")
                .accessibilityLabel(Text("session.action.stop"))
                .accessibilityHint(Text("a11y.session.stop.hint"))
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    // MARK: - Display

    private var displayName: String {
        if let ex = exercise {
            return Locale.current.language.languageCode?.identifier == "ja" ? ex.nameJa : ex.nameEn
        }
        return item.slug
    }
}

extension SessionSection {
    var titleKey: LocalizedStringKey {
        switch self {
        case .warmup:   return "session.section.warmup"
        case .main:     return "session.section.main"
        case .cooldown: return "session.section.cooldown"
        }
    }
}
