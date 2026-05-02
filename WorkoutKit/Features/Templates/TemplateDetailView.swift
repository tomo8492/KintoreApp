// MARK: - TemplateDetailView
// CLAUDE.md §1.1 F-05 / §-1.14 / §11.4 準拠。
// テンプレートの中身を表示する画面。
//   ・種目リスト(Exercise.slug を Library から解決して名称・部位を表示)
//   ・所要時間(B1 未実装のため概算: 種目数 × 6 分)
//   ・対象部位(primary/secondary を集合で集計)
//   ・「使う」ボタン → 親 View の onUse コールバック経由で SessionStore へ渡す想定

import SwiftUI
import SwiftData

struct TemplateDetailView: View {
    let template: Template
    let store: TemplateStore
    /// 「使う」が押されたとき呼ばれる。親が pendingUseOutput に詰めて sheet を出す。
    let onUse: (PendingUse) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var resolvedExercises: [ResolvedExercise] = []

    var body: some View {
        List {
            Section(header: Text("templates.detail.summary")) {
                summaryRow(label: Text("templates.detail.goal"),
                           value: GoalLabels.displayName(for: template.defaultGoal))
                summaryRow(label: Text("templates.detail.estimated"),
                           value: estimatedTimeText)
                summaryRow(label: Text("templates.detail.muscles"),
                           value: targetMusclesText)
            }

            Section(header: Text("templates.detail.exercises")) {
                if resolvedExercises.isEmpty {
                    Text("templates.detail.empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(resolvedExercises) { entry in
                        ExerciseRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle(Text(TemplateNaming.localizedDisplayName(for: template)))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    fireUse()
                } label: {
                    Label {
                        Text("templates.use")
                    } icon: {
                        Image(systemName: "play.fill")
                    }
                }
                .accessibilityIdentifier("templates.useButton")
            }
        }
        .task {
            await resolve()
        }
    }

    // MARK: - Summary helpers

    private var estimatedTimeText: String {
        let minutes = max(template.exerciseSlugs.count * 6, 5)
        return String(format: String(localized: "templates.detail.minutes"), minutes)
    }

    private var targetMusclesText: String {
        var muscles: Set<Muscle> = []
        for entry in resolvedExercises {
            if let exercise = entry.exercise {
                muscles.insert(exercise.primaryMuscle)
                exercise.secondaryMuscles.forEach { muscles.insert($0) }
            }
        }
        if muscles.isEmpty {
            return String(localized: "templates.detail.musclesUnknown")
        }
        let names = muscles.map { MuscleLabels.displayName(for: $0) }.sorted()
        return names.joined(separator: ", ")
    }

    @ViewBuilder
    private func summaryRow(label: Text, value: String) -> some View {
        HStack {
            label
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Resolution (slug → Exercise)

    private func resolve() async {
        let slugs = template.exerciseSlugs
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { slugs.contains($0.slug) }
        )
        let fetched: [Exercise]
        do {
            fetched = try modelContext.fetch(descriptor)
        } catch {
            Logger.data.error("TemplateDetailView fetch failed: \(error.localizedDescription, privacy: .public)")
            fetched = []
        }
        let bySlug = Dictionary(uniqueKeysWithValues: fetched.map { ($0.slug, $0) })
        resolvedExercises = slugs.map { slug in
            ResolvedExercise(slug: slug, exercise: bySlug[slug])
        }
    }

    // MARK: - Use

    private func fireUse() {
        let output = store.makeGeneratorOutput(from: template)
        onUse(PendingUse(
            output: output,
            displayName: TemplateNaming.localizedDisplayName(for: template)
        ))
    }
}

// MARK: - ResolvedExercise

private struct ResolvedExercise: Identifiable {
    let slug: String
    let exercise: Exercise?
    var id: String { slug }
}

// MARK: - ExerciseRow

private struct ExerciseRow: View {
    let entry: ResolvedExercise

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let exercise = entry.exercise {
                    Text(displayName(for: exercise))
                        .font(.body)
                    Text(MuscleLabels.displayName(for: exercise.primaryMuscle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(entry.slug)
                        .font(.body.monospaced())
                    Text("templates.detail.exerciseMissing")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
        }
    }

    private func displayName(for exercise: Exercise) -> String {
        let isJa = Locale.current.language.languageCode?.identifier == "ja"
        return isJa ? exercise.nameJa : exercise.nameEn
    }
}

// MARK: - MuscleLabels

/// Muscle の表示用ラベル。Localizable.xcstrings で日英切替。
/// `String(localized:)` は静的キー専用なので、ランタイム文字列キーには
/// `NSLocalizedString` を使う(xcstrings は両 API に対応)。
enum MuscleLabels {
    static func displayName(for muscle: Muscle) -> String {
        NSLocalizedString("muscle.\(muscle.rawValue)", comment: "Muscle label")
    }
}
