// MARK: - TemplatesView
// CLAUDE.md §1.1 F-05 / §-1.14(Paywall) / §11.4(NGリスト) 準拠。
// テンプレ一覧画面。アクション:
//   ・「使う」(Free): GeneratorOutput を組み立てて返す(B2 SessionStore に渡す想定)
//   ・「複製」(Free): プリセットを user-created としてコピー
//   ・「編集」(Pro): customTemplates ゲート不通過時は Paywall
//   ・「削除」(Pro): 同上(プリセットを Pro 経由でだけ消せる)
// View には @State / @Observable Store を直接持たせる(ViewModel 禁止)。
// シート群とローカライズ補助は TemplateSheets.swift / TemplateSupport.swift に分離。

import SwiftUI
import SwiftData

struct TemplatesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appDependency) private var dependency

    /// SwiftData Context は Environment 経由で受け取るので Store は遅延生成する。
    @State private var store: TemplateStore?

    /// Paywall シートの表示状態と、どの Pro 機能でブロックされたかの記録。
    @State private var paywallFeature: ProFeature?

    /// 「使う」を押したテンプレ。本来は SessionStore に渡すが B2 未実装のため
    /// 確認用の sheet で出力内容を表示する。
    @State private var pendingUseOutput: PendingUse?

    /// 削除確認の対象。
    @State private var pendingDelete: Template?

    /// 新規作成シート(Pro 機能のため通過時のみ表示)。
    @State private var showingCreate = false

    // MARK: - Body

    var body: some View {
        Group {
            if let store {
                content(store: store)
            } else {
                ProgressView()
                    .task { initializeStoreIfNeeded() }
            }
        }
        .navigationTitle(Text("templates.title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    handleAdd()
                } label: {
                    Label {
                        Text("templates.add")
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
                .accessibilityIdentifier("templates.addButton")
            }
        }
        .sheet(item: $paywallFeature) { feature in
            PaywallStubView(feature: feature)
        }
        .sheet(isPresented: $showingCreate) {
            if let store {
                CreateTemplateSheet(store: store) { error in
                    handle(error: error)
                }
            }
        }
        .sheet(item: $pendingUseOutput) { use in
            UseTemplatePreviewSheet(output: use.output, templateName: use.displayName)
        }
        .alert(
            Text("templates.delete.title"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { template in
            Button(role: .destructive) {
                performDelete(template)
            } label: {
                Text("templates.delete.confirm")
            }
            Button(role: .cancel) {
                pendingDelete = nil
            } label: {
                Text("common.cancel")
            }
        } message: { _ in
            Text("templates.delete.message")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(store: TemplateStore) -> some View {
        if store.templates.isEmpty {
            ContentUnavailableView {
                Label {
                    Text("templates.empty.title")
                } icon: {
                    Image(systemName: "tray")
                }
            } description: {
                Text("templates.empty.message")
            }
        } else {
            List {
                ForEach(store.templates) { template in
                    NavigationLink {
                        TemplateDetailView(
                            template: template,
                            store: store,
                            onUse: { use in pendingUseOutput = use }
                        )
                    } label: {
                        TemplateRow(template: template)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            handleDelete(template)
                        } label: {
                            Label {
                                Text("templates.delete")
                            } icon: {
                                Image(systemName: "trash")
                            }
                        }
                        Button {
                            handleEdit(template)
                        } label: {
                            Label {
                                Text("templates.edit")
                            } icon: {
                                Image(systemName: "pencil")
                            }
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            handleDuplicate(template)
                        } label: {
                            Label {
                                Text("templates.duplicate")
                            } icon: {
                                Image(systemName: "plus.square.on.square")
                            }
                        }
                        .tint(.indigo)
                    }
                }
            }
        }
    }

    // MARK: - Action handlers

    private func initializeStoreIfNeeded() {
        guard store == nil else { return }
        let s = TemplateStore(context: modelContext)
        s.reload()
        store = s
    }

    private func handleAdd() {
        guard dependency.proGate.check(.customTemplates) else {
            paywallFeature = .customTemplates
            return
        }
        showingCreate = true
    }

    private func handleEdit(_ template: Template) {
        guard dependency.proGate.check(.customTemplates) else {
            paywallFeature = .customTemplates
            return
        }
        // 詳細画面に編集導線がある想定。ここでは Paywall ガードのみ通す。
        // (E1 範囲では編集 UI は最小実装)
    }

    private func handleDelete(_ template: Template) {
        guard dependency.proGate.check(.customTemplates) else {
            paywallFeature = .customTemplates
            return
        }
        pendingDelete = template
    }

    private func handleDuplicate(_ template: Template) {
        guard let store else { return }
        let newName = TemplateNaming.duplicateName(for: TemplateNaming.localizedDisplayName(for: template))
        do {
            _ = try store.duplicate(template, newName: newName)
        } catch {
            handle(error: error)
        }
    }

    private func performDelete(_ template: Template) {
        guard let store else { return }
        do {
            try store.delete(template)
            pendingDelete = nil
        } catch {
            handle(error: error)
        }
    }

    private func handle(error: Error) {
        Logger.app.error("TemplatesView error: \(error.localizedDescription, privacy: .public)")
    }
}

// MARK: - Row

private struct TemplateRow: View {
    let template: Template

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.isUserCreated ? "person.crop.square" : "square.stack.3d.up")
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(TemplateNaming.localizedDisplayName(for: template))
                    .font(.body)
                Text(TemplateNaming.subtitle(for: template))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        TemplatesView()
    }
    .modelContainer(for: SchemaV1.self, inMemory: true)
}
