// MARK: - ExerciseListView
// CLAUDE.md §1.1 F-02 / §-1.15 / §11 準拠。
// SwiftData の @Query で Exercise 全件を取得し、フィルタ + 全文検索を提供する。
// iPhone(compact)は NavigationStack、iPad(regular)は NavigationSplitView。
// 検索/フィルタ状態は @State で View 直持ち(ViewModel 禁止 §11.4)。

import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    // 同梱種目は最大 ~150 件想定(§-1.10)。インメモリで filter する方が
    // SwiftData の dynamic predicate を組み替えるより素直で速い。
    @Query(sort: [SortDescriptor(\Exercise.nameJa)]) private var allExercises: [Exercise]

    // --- フィルタ / 検索 state(View 直持ち) -------------------------
    @State private var searchText: String = ""
    @State private var typeFilter: ExerciseType?
    @State private var muscleFilter: Muscle?
    @State private var equipmentFilter: Equipment?
    @State private var mechanicsFilter: MechanicsType?

    // --- iPad 選択 ----------------------------------------------------
    @State private var selectedSlug: String?

    // MARK: - Body

    var body: some View {
        if sizeClass == .regular {
            iPadBody
        } else {
            iPhoneBody
        }
    }

    // MARK: - iPhone

    private var iPhoneBody: some View {
        NavigationStack {
            listContent
                .navigationTitle("Library")
                .navigationDestination(for: String.self) { slug in
                    if let exercise = allExercises.first(where: { $0.slug == slug }) {
                        ExerciseDetailView(exercise: exercise)
                    } else {
                        ContentUnavailableView(
                            "Exercise not found",
                            systemImage: "questionmark.circle"
                        )
                    }
                }
        }
    }

    // MARK: - iPad

    private var iPadBody: some View {
        NavigationSplitView {
            listContent
                .navigationTitle("Library")
        } detail: {
            if let slug = selectedSlug,
               let exercise = allExercises.first(where: { $0.slug == slug }) {
                ExerciseDetailView(exercise: exercise)
            } else {
                ContentUnavailableView(
                    "Select an exercise",
                    systemImage: "books.vertical",
                    description: Text("Tap an exercise to see details")
                )
            }
        }
    }

    // MARK: - Shared list content

    private var listContent: some View {
        Group {
            if allExercises.isEmpty {
                ContentUnavailableView(
                    "No exercises",
                    systemImage: "books.vertical",
                    description: Text("Exercise library is empty")
                )
            } else if filtered.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "magnifyingglass",
                    description: Text("No exercises match your filters")
                )
            } else {
                exerciseList
            }
        }
        .searchable(text: $searchText, prompt: Text("Search exercises"))
        .toolbar { filterToolbar }
    }

    @ViewBuilder
    private var exerciseList: some View {
        if sizeClass == .regular {
            // iPad: List selection を使い、NavigationSplitView の detail に表示
            List(selection: $selectedSlug) {
                ForEach(filtered, id: \.slug) { exercise in
                    ExerciseRowView(exercise: exercise)
                        .tag(exercise.slug as String?)
                }
            }
            .listStyle(.plain)
        } else {
            // iPhone: NavigationLink(value:) で navigationDestination にプッシュ
            List {
                ForEach(filtered, id: \.slug) { exercise in
                    NavigationLink(value: exercise.slug) {
                        ExerciseRowView(exercise: exercise)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var filterToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Type", selection: $typeFilter) {
                    Text("All").tag(ExerciseType?.none)
                    ForEach(ExerciseType.allCases, id: \.self) { t in
                        Text(LibraryDisplay.typeName(t)).tag(ExerciseType?.some(t))
                    }
                }

                Picker("Muscle", selection: $muscleFilter) {
                    Text("All").tag(Muscle?.none)
                    ForEach(Muscle.allCases, id: \.self) { m in
                        Text(LibraryDisplay.muscleName(m)).tag(Muscle?.some(m))
                    }
                }

                Picker("Equipment", selection: $equipmentFilter) {
                    Text("All").tag(Equipment?.none)
                    ForEach(Equipment.allCases, id: \.self) { e in
                        Text(LibraryDisplay.equipmentName(e)).tag(Equipment?.some(e))
                    }
                }

                Picker("Mechanics", selection: $mechanicsFilter) {
                    Text("All").tag(MechanicsType?.none)
                    ForEach(MechanicsType.allCases, id: \.self) { m in
                        Text(LibraryDisplay.mechanicsName(m)).tag(MechanicsType?.some(m))
                    }
                }

                Divider()

                Button("Reset filters", role: .destructive) {
                    resetFilters()
                }
                .disabled(!hasAnyFilter)
            } label: {
                Label("Filters", systemImage: hasAnyFilter
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel(Text("a11y.library.filters"))
            .accessibilityHint(Text("a11y.library.filters.hint"))
            .accessibilityValue(Text(hasAnyFilter
                                     ? "a11y.library.filters.active"
                                     : "a11y.library.filters.none"))
        }
    }

    // MARK: - Filter / Search logic

    private var hasAnyFilter: Bool {
        typeFilter != nil
            || muscleFilter != nil
            || equipmentFilter != nil
            || mechanicsFilter != nil
            || !searchText.isEmpty
    }

    private func resetFilters() {
        typeFilter = nil
        muscleFilter = nil
        equipmentFilter = nil
        mechanicsFilter = nil
        searchText = ""
    }

    private var filtered: [Exercise] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return allExercises.filter { ex in
            if let t = typeFilter, ex.type != t { return false }
            if let m = muscleFilter,
               ex.primaryMuscle != m && !ex.secondaryMuscles.contains(m) {
                return false
            }
            if let eq = equipmentFilter, !ex.equipment.contains(eq) { return false }
            if let mech = mechanicsFilter, ex.mechanicsType != mech { return false }

            guard !trimmed.isEmpty else { return true }
            return Self.matches(exercise: ex, query: trimmed)
        }
    }

    /// name / nameJa / description / descriptionJa / slug の5フィールド横断検索。
    /// 大文字小文字を無視。日本語は単純な部分一致で十分(将来 ICU 正規化検討)。
    private static func matches(exercise ex: Exercise, query: String) -> Bool {
        let haystacks: [String] = [
            ex.nameEn,
            ex.nameJa,
            ex.descriptionEn,
            ex.descriptionJa,
            ex.slug,
            ex.slugJa,
        ]
        return haystacks.contains { $0.lowercased().contains(query) }
    }
}

#Preview("iPhone") {
    ExerciseListView()
        .modelContainer(for: SchemaV1.models, inMemory: true)
}

#Preview("iPad", traits: .landscapeLeft) {
    ExerciseListView()
        .modelContainer(for: SchemaV1.models, inMemory: true)
}
