// MARK: - QuickLogView
// Phase 2-2 (Watch 単体記録) 準拠。
//
// iPhone から同期された「最近使った種目」一覧を表示するルート画面。
// 未同期(iPhone 側でまだワークアウトしていない)場合は空状態を出す。
// 行をタップすると LogSetView に遷移し、reps / weight を入力して記録する。

import SwiftUI

struct QuickLogView: View {
    @Environment(WatchSyncClient.self) private var syncClient

    var body: some View {
        NavigationStack {
            Group {
                if syncClient.recentExercises.isEmpty {
                    emptyState
                } else {
                    List(syncClient.recentExercises) { exercise in
                        NavigationLink {
                            LogSetView(exercise: exercise)
                        } label: {
                            exerciseRow(exercise)
                        }
                    }
                }
            }
            .navigationTitle(Text("watch.quicklog.title"))
        }
    }

    // MARK: - Empty state

    /// ContentUnavailableView 相当(watchOS では素の VStack で組む)。
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("watch.quicklog.empty")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Row

    private func exerciseRow(_ exercise: WatchRecentExercise) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(displayName(for: exercise))
                .font(.headline)
                .lineLimit(1)
            if let lastWeightKg = exercise.lastWeightKg, let lastReps = exercise.lastReps {
                Text("\(lastWeightKg.formatted(.number.precision(.fractionLength(0...1)))) kg × \(lastReps)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 現在のロケール言語コードに応じて nameJa / nameEn を返す。
    /// WorkoutKit/Domain/Models/Exercise.swift の localizedName と同じパターン。
    private func displayName(for exercise: WatchRecentExercise) -> String {
        Locale.current.language.languageCode?.identifier == "ja" ? exercise.nameJa : exercise.nameEn
    }
}
