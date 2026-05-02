// MARK: - SessionSetInputPanel
// 現在セットの入力 UI。CLAUDE.md §1.1 F-03 / §-1.4 準拠。
// - 重量は kg を Stepper で 0.5 きざみ。lbs 設定は v1.0 では SessionStore 内で kg 直入力に
//   留め、Settings 機能(E3)導入時に UnitsFormatter.toKilograms 経由の双方向変換を入れる。
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
            Text(displayName)
                .font(.title3.bold())
            let setText = String(
                localized: "session.input.current-set",
                defaultValue: "セット %lld / %lld"
            )
            Text(String(format: setText, store.currentSetIndex + 1, item.plannedSetCount))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
            Spacer()
            Text(display(value.wrappedValue))
                .font(.body.monospacedDigit())
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
        }
    }

    // MARK: - Weight row(0.5 kg 刻み)

    private var weightRow: some View {
        HStack {
            Text("session.input.weight")
                .frame(width: 80, alignment: .leading)
            Spacer()
            Text(UnitsFormatter.formatWeight(store.inputWeightKg, preference: .kilograms))
                .font(.body.monospacedDigit())
            Stepper(
                "",
                value: $store.inputWeightKg,
                in: 0...500,
                step: 0.5
            )
            .labelsHidden()
        }
    }

    // MARK: - RPE row(任意、6.0〜10.0)

    private var rpeRow: some View {
        HStack {
            Text("session.input.rpe")
                .frame(width: 80, alignment: .leading)
            Spacer()
            if let rpe = store.inputRpe {
                Text(String(format: "%.1f", rpe))
                    .font(.body.monospacedDigit())
            } else {
                Text("session.input.rpe.none")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Stepper(
                "",
                onIncrement: { adjustRpe(by: 0.5) },
                onDecrement: { adjustRpe(by: -0.5) }
            )
            .labelsHidden()
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button(action: onSkip) {
                    Text("session.action.skip")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button(role: .destructive, action: onAbort) {
                    Text("session.action.stop")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.10))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
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
