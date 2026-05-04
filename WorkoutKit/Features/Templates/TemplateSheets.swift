// MARK: - TemplateSheets
// CLAUDE.md §1.1 F-05 / §-1.14 / §11.4 準拠。
// テンプレ機能の sheet 群:
//   ・CreateTemplateSheet — Pro ゲート通過後に表示する新規作成フォーム
// View 本体ファイルを 300 行以下に保つための分割(§11.4)。
// (旧 UseTemplatePreviewSheet は B2 完了で削除。「使う」は SessionView を fullScreenCover
//  で直接立ち上げる。旧 PaywallStubView は本物の PaywallView に置換済み。)

import SwiftUI

// MARK: - CreateTemplateSheet

struct CreateTemplateSheet: View {
    let store: TemplateStore
    let onError: (Error) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var goal: Goal = .hypertrophy
    @State private var slugsText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("templates.create.name")) {
                    TextField("templates.create.namePlaceholder", text: $name)
                }
                Section(header: Text("templates.create.goal")) {
                    Picker(selection: $goal) {
                        ForEach(Goal.allCases, id: \.self) { g in
                            Text(GoalLabels.displayName(for: g)).tag(g)
                        }
                    } label: {
                        Text("templates.create.goal")
                    }
                }
                Section {
                    TextField(
                        "templates.create.slugsPlaceholder",
                        text: $slugsText,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                } header: {
                    Text("templates.create.slugs")
                } footer: {
                    Text("templates.create.slugsHint")
                }
            }
            .navigationTitle(Text("templates.create.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("common.cancel")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text("common.save")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let slugs = slugsText
            .split(whereSeparator: { $0.isNewline || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        do {
            _ = try store.create(name: name, exerciseSlugs: slugs, goal: goal)
            dismiss()
        } catch {
            onError(error)
        }
    }
}

