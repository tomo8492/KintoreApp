// MARK: - ManualEntryView
// CLAUDE.md §1.1 F-04 / §-1.14 (manualEntry Pro 機能) / §11.4 NG リスト準拠。
// 「アプリ外で実施した種目を後から手動でログする」画面。
//
// アクセス制御は呼び出し側 (HistoryView) が PaywallTrigger.gate(.manualEntry) で
// 判定済み。本 View は Pro 解放済みである前提で開く。
//
// 設計:
// - @State / @Observable Store 直挿し。ViewModel 禁止 (§11.4)。
// - 重量は内部単位 kg で保持、表示は UnitsFormatter 経由 (§-1.4)。
// - 日付は過去のみ受け付ける (DatePicker の in: 範囲で制約)。
// - 保存時に WorkoutSession.isManualEntry = true で SwiftData にコミット。
// - finishedAt は startedAt + (推定セット時間) を入れる。実時間は未計測のため、
//   60s × セット数 を最低 60s で丸めるだけの簡易推定。
//
// 関連ファイル:
// - ManualEntryStore.swift           : 状態 / Draft / 保存ロジック
// - ManualEntryExercisePicker.swift  : 種目複数選択シート
// - ManualEntrySetEditor.swift       : 1 セット行のエディタ

import SwiftUI
import SwiftData

@MainActor
struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var store = ManualEntryStore()
    @State private var showingPicker: Bool = false
    @State private var saveErrorPresented: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                metaSection
                exercisesSection
                notesSection
            }
            .navigationTitle("manual-entry.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingPicker) {
                ManualEntryExercisePicker(
                    alreadySelectedSlugs: Set(store.drafts.map(\.slug)),
                    onCommit: { picked in
                        store.addExercises(picked)
                    }
                )
            }
            .alert(
                "manual-entry.save-error.title",
                isPresented: $saveErrorPresented
            ) {
                Button("Close", role: .cancel) {}
            } message: {
                Text("manual-entry.save-error.message")
            }
        }
    }

    // MARK: - Sections

    private var metaSection: some View {
        Section {
            DatePicker(
                "manual-entry.date",
                selection: $store.sessionDate,
                in: ...Date.now,
                displayedComponents: [.date, .hourAndMinute]
            )

            Picker("manual-entry.goal", selection: $store.goal) {
                ForEach(Goal.allCases, id: \.self) { goal in
                    Text(LocalizedStringKey("goal.\(goal.rawValue)")).tag(goal)
                }
            }
        } header: {
            Text("manual-entry.section.meta")
        } footer: {
            Text("manual-entry.section.meta.footer")
        }
    }

    @ViewBuilder
    private var exercisesSection: some View {
        if store.drafts.isEmpty {
            Section {
                Button {
                    showingPicker = true
                } label: {
                    Label("manual-entry.add-exercises", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("manual-entry.section.exercises")
            } footer: {
                Text("manual-entry.section.exercises.footer.empty")
            }
        } else {
            ForEach(store.drafts) { draft in
                ManualEntryExerciseSection(
                    draft: draft,
                    onUpdateSet: { setID, mutate in
                        guard let exerciseIdx = store.drafts.firstIndex(where: { $0.id == draft.id }),
                              let setIdx = store.drafts[exerciseIdx].sets.firstIndex(where: { $0.id == setID })
                        else { return }
                        mutate(&store.drafts[exerciseIdx].sets[setIdx])
                    },
                    onAddSet: { store.addSet(toExerciseID: draft.id) },
                    onRemoveSet: { setID in
                        store.removeSet(exerciseID: draft.id, setID: setID)
                    },
                    onRemoveExercise: { store.removeExercise(id: draft.id) }
                )
            }

            Section {
                Button {
                    showingPicker = true
                } label: {
                    Label("manual-entry.add-more-exercises", systemImage: "plus.circle")
                }
            }
        }
    }

    private var notesSection: some View {
        Section {
            TextField(
                "manual-entry.notes.placeholder",
                text: $store.notes,
                axis: .vertical
            )
            .lineLimit(2...6)
        } header: {
            Text("manual-entry.section.notes")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .accessibilityHint(Text("a11y.manual-entry.cancel.hint"))
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("manual-entry.save") {
                handleSave()
            }
            .disabled(!store.canSave)
            .accessibilityHint(Text("a11y.manual-entry.save.hint"))
        }
    }

    // MARK: - Actions

    private func handleSave() {
        let saved = store.save(
            modelContext: modelContext,
            exerciseLookup: { id in modelContext.model(for: id) as? Exercise }
        )
        if saved != nil {
            dismiss()
        } else {
            saveErrorPresented = true
        }
    }
}

#Preview {
    ManualEntryView()
        .modelContainer(for: SchemaV1.models, inMemory: true)
}
