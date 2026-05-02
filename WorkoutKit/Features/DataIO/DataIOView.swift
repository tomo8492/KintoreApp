// MARK: - DataIOView
// CLAUDE.md §1.1 F-06 / §-1.14 / §11.4 準拠。
// File App / 共有シート経由で CSV / JSON を取り込み、履歴を CSV エクスポートする UI。
// すべての import / export ボタンは ProFeatureGate.check(.csvImport / .csvExport) でゲートする。
// Pro 未購入時はボタンを無効化し、タップ時は Paywall シグナル(AppError.proRequired)を
// alert で提示する(NGリスト規約: ハードコード禁止 / Paywall を起動直後に出さない)。

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataIOView: View {
    @Environment(\.appDependency) private var dependency
    @Environment(\.modelContext) private var modelContext

    @State private var store = DataIOStore()

    var body: some View {
        Form {
            Section {
                importButton(
                    title: "data-io.import.csv.title",
                    subtitle: "data-io.import.csv.subtitle",
                    feature: .csvImport,
                    pickerKind: .csv
                )
                importButton(
                    title: "data-io.import.json.title",
                    subtitle: "data-io.import.json.subtitle",
                    feature: .csvImport,
                    pickerKind: .json
                )
            } header: {
                Text("data-io.section.import")
            } footer: {
                Text("data-io.section.import.footer")
            }

            Section {
                Button {
                    runExport()
                } label: {
                    Label("data-io.export.csv", systemImage: "square.and.arrow.up")
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .disabled(!dependency.proGate.check(.csvExport) || store.isWorking)
                .accessibilityLabel(Text("data-io.export.csv"))
                .accessibilityHint(Text("a11y.data-io.export.hint"))
                .accessibilityAddTraits(.isButton)
            } header: {
                Text("data-io.section.export")
            }

            if let result = store.lastResult {
                Section("data-io.section.result") {
                    Text(result)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("data-io.title")
        .fileImporter(
            isPresented: $store.isPickerPresented,
            allowedContentTypes: store.pickerKind.contentTypes,
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .fileExporter(
            isPresented: $store.isExporterPresented,
            document: store.exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "workoutkit-history"
        ) { result in
            store.handleExportFinished(result)
        }
        .alert(
            "data-io.alert.title",
            isPresented: $store.isAlertPresented,
            presenting: store.alertMessage
        ) { _ in
            Button("data-io.alert.ok", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func importButton(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        feature: ProFeature,
        pickerKind: DataIOStore.PickerKind
    ) -> some View {
        Button {
            // Pro 判定は必ずゲート経由(NGリスト: if userIsPro 直書き禁止)
            guard dependency.proGate.check(feature) else {
                store.showProPaywall(for: feature)
                return
            }
            store.beginImport(kind: pickerKind)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: pickerKind.systemImage)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .disabled(store.isWorking)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text("a11y.data-io.import.hint"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Handlers

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                try store.runImport(url: url, modelContext: modelContext)
            } catch {
                store.presentError(error)
            }
        case .failure(let error):
            store.presentError(error)
        }
    }

    private func runExport() {
        // Export も Pro ゲート(disabled でも保険として再チェック)
        guard dependency.proGate.check(.csvExport) else {
            store.showProPaywall(for: .csvExport)
            return
        }
        do {
            try store.prepareExport(modelContext: modelContext)
        } catch {
            store.presentError(error)
        }
    }
}

#Preview("Free user") {
    NavigationStack {
        DataIOView()
    }
}

#Preview("Pro user") {
    NavigationStack {
        DataIOView()
    }
}
