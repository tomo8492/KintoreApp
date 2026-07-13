// MARK: - LogSetView
// Phase 2-2 (Watch 単体記録) 準拠。
//
// reps / weight を Stepper で調整し、「セットを記録」で WatchSyncClient.log(_:) を
// 呼んで iPhone へ transferUserInfo する。記録後はチェックマークで確認表示 → 1 秒後に
// 前の画面へ自動で戻る(ワークアウト中に画面操作を最小化する CLAUDE.md §7-1 方針)。

import SwiftUI
import WatchKit

struct LogSetView: View {
    let exercise: WatchRecentExercise

    @Environment(WatchSyncClient.self) private var syncClient
    @Environment(\.dismiss) private var dismiss

    @State private var reps: Int
    @State private var weightKg: Double
    @State private var didSave = false

    init(exercise: WatchRecentExercise) {
        self.exercise = exercise
        _reps = State(initialValue: exercise.lastReps ?? 10)
        _weightKg = State(initialValue: exercise.lastWeightKg ?? 20)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(displayName)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Stepper(value: $reps, in: 1...99) {
                    labeledValue(titleKey: "watch.quicklog.reps", value: "\(reps)")
                }
                .disabled(didSave)

                Stepper(value: $weightKg, in: 0...500, step: 2.5) {
                    labeledValue(titleKey: "watch.quicklog.weight", value: weightText)
                }
                .disabled(didSave)

                if didSave {
                    Label {
                        Text("watch.quicklog.saved")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .foregroundStyle(.green)
                    .font(.headline)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button {
                        logSet()
                    } label: {
                        Text("watch.quicklog.logset")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }

                Text("watch.quicklog.sync-note")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .navigationTitle(displayName)
    }

    private var displayName: String {
        Locale.current.language.languageCode?.identifier == "ja" ? exercise.nameJa : exercise.nameEn
    }

    private var weightText: String {
        "\(weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }

    private func labeledValue(titleKey: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(titleKey)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func logSet() {
        let set = WatchLoggedSet(
            id: UUID(),
            slug: exercise.slug,
            reps: reps,
            weightKg: weightKg,
            loggedAt: .now
        )
        syncClient.log(set)
        WKInterfaceDevice.current().play(.success)

        withAnimation {
            didSave = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        }
    }
}
