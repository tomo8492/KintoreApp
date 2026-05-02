// MARK: - ManualEntryExercisePicker
// CLAUDE.md §1.1 F-04 / §11.4 準拠。
// ManualEntryView から呼ばれる「種目複数選択」シート。
// ExerciseListView と同じデータソース (SwiftData @Query) を使い、検索 + 部位フィルタを提供する。
//
// 単一選択の遷移ナビゲーションは ExerciseListView (D1) が担うが、
// 手動ログでは「複数選びまとめて追加」が UX 上必要なので、本コンポーネントは
// 独立した multi-select 専用ビューとして実装する (ListView を再利用しようとすると
// detail 遷移の責務が混ざるため分離)。

import SwiftUI
import SwiftData

@MainActor
struct ManualEntryExercisePicker: View {
    /// すでに ManualEntryStore に追加済みの slug 集合。重複追加を抑止し、
    /// 行に「追加済み」表示を出すために使う。
    let alreadySelectedSlugs: Set<String>
    /// 「追加」ボタン押下時に呼ばれる。新規選択分だけが渡される。
    let onCommit: ([Exercise]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @Query(sort: [SortDescriptor(\Exercise.nameJa)]) private var allExercises: [Exercise]

    @State private var searchText: String = ""
    @State private var muscleFilter: Muscle?
    @State private var picked: Set<String> = []

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("manual-entry.picker.title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .searchable(text: $searchText, prompt: Text("Search exercises"))
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if allExercises.isEmpty {
            ContentUnavailableView {
                Label("Exercise library is empty", systemImage: "books.vertical")
            } description: {
                Text("manual-entry.picker.empty.subtitle")
            }
        } else if filtered.isEmpty {
            ContentUnavailableView {
                Label("No matches", systemImage: "magnifyingglass")
            } description: {
                Text("manual-entry.picker.no-matches.subtitle")
            }
        } else {
            list
        }
    }

    private var list: some View {
        List {
            muscleFilterSection
            ForEach(filtered, id: \.slug) { exercise in
                row(for: exercise)
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var muscleFilterSection: some View {
        Section {
            Picker("Muscle", selection: $muscleFilter) {
                Text("All").tag(Muscle?.none)
                ForEach(Muscle.allCases, id: \.self) { m in
                    Text(LibraryDisplay.muscleName(m)).tag(Muscle?.some(m))
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for exercise: Exercise) -> some View {
        let isAlreadyAdded = alreadySelectedSlugs.contains(exercise.slug)
        let isPicked = picked.contains(exercise.slug)

        Button {
            guard !isAlreadyAdded else { return }
            if isPicked {
                picked.remove(exercise.slug)
            } else {
                picked.insert(exercise.slug)
            }
        } label: {
            HStack(spacing: 12) {
                checkmark(isPicked: isPicked, isAlreadyAdded: isAlreadyAdded)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(for: exercise))
                        .font(.body)
                        .foregroundStyle(isAlreadyAdded ? .secondary : .primary)
                    HStack(spacing: 6) {
                        Text(LibraryDisplay.muscleName(exercise.primaryMuscle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if isAlreadyAdded {
                            Text("manual-entry.picker.already-added")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyAdded)
    }

    private func checkmark(isPicked: Bool, isAlreadyAdded: Bool) -> some View {
        Group {
            if isAlreadyAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tertiary)
            } else if isPicked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.title3)
        .frame(width: 28)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                commit()
            } label: {
                if picked.isEmpty {
                    Text("manual-entry.picker.add")
                } else {
                    Text(verbatim: countedAddTitle)
                }
            }
            .disabled(picked.isEmpty)
        }
    }

    // MARK: - Filtering

    private var filtered: [Exercise] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allExercises.filter { ex in
            if let m = muscleFilter,
               ex.primaryMuscle != m && !ex.secondaryMuscles.contains(m) {
                return false
            }
            guard !trimmed.isEmpty else { return true }
            return matches(exercise: ex, query: trimmed)
        }
    }

    private func matches(exercise ex: Exercise, query: String) -> Bool {
        let haystacks: [String] = [
            ex.nameEn,
            ex.nameJa,
            ex.slug,
            ex.slugJa,
        ]
        return haystacks.contains { $0.lowercased().contains(query) }
    }

    // MARK: - Helpers

    private func displayName(for exercise: Exercise) -> String {
        let langCode = locale.language.languageCode?.identifier
        if langCode == "ja", !exercise.nameJa.isEmpty {
            return exercise.nameJa
        }
        return exercise.nameEn.isEmpty ? exercise.slug : exercise.nameEn
    }

    private var countedAddTitle: String {
        let template = String(
            localized: "manual-entry.picker.add.count",
            defaultValue: "追加 (%lld)"
        )
        return String(format: template, picked.count)
    }

    private func commit() {
        let chosen = allExercises.filter { picked.contains($0.slug) }
        onCommit(chosen)
        dismiss()
    }
}

#Preview {
    ManualEntryExercisePicker(
        alreadySelectedSlugs: [],
        onCommit: { _ in }
    )
    .modelContainer(for: SchemaV1.models, inMemory: true)
}
