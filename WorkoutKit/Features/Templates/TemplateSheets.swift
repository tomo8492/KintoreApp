// MARK: - TemplateSheets
// CLAUDE.md §1.1 F-05 / §-1.14 / §11.4 準拠。
// テンプレ機能の sheet 群:
//   ・CreateTemplateSheet — Pro ゲート通過後に表示する新規作成フォーム
//   ・UseTemplatePreviewSheet — 「使う」確認(B2 SessionStore 未実装のためスタブ表示)
//   ・PaywallStubView — F2 Paywall 未実装のための最小代替(§-1.14 のトリガーで起動)
// View 本体ファイルを 300 行以下に保つための分割(§11.4)。

import SwiftUI

// MARK: - UseTemplatePreviewSheet

struct UseTemplatePreviewSheet: View {
    let output: GeneratorOutput
    let templateName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(templateName).font(.headline)
                    Text("templates.use.b2Pending")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section(header: Text("templates.detail.exercises")) {
                    if output.main.isEmpty {
                        Text("templates.detail.empty")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(output.main.enumerated()), id: \.offset) { _, slug in
                            Text(slug).font(.body.monospaced())
                        }
                    }
                }
            }
            .navigationTitle(Text("templates.use.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("common.done")
                    }
                }
            }
        }
    }
}

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

// MARK: - PaywallStubView

/// E1 範囲では F2 Paywall がまだ無いので最小スタブで Paywall 出現確認だけ取る。
/// 実装は F2 で差し替える(§-1.14)。
struct PaywallStubView: View {
    let feature: ProFeature
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                Text("paywall.title").font(.title2.bold())
                Text("paywall.message").multilineTextAlignment(.center)
                Text(verbatim: feature.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("paywall.dismiss")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle(Text("paywall.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
