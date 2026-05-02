// MARK: - DataIOStore
// DataIOView 用の @Observable Store。
// CLAUDE.md "View には @State または @Observable Store を直接持たせる(ViewModel 禁止)" 規約。
// File App / 共有シートからの URL を受け取り、Importer / Exporter を呼び出す。

import Foundation
import Observation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@Observable
@MainActor
final class DataIOStore {

    // MARK: - Picker

    enum PickerKind: Equatable {
        case csv
        case json

        var contentTypes: [UTType] {
            switch self {
            case .csv:  return [.commaSeparatedText, .plainText]
            case .json: return [.json]
            }
        }
        var systemImage: String {
            switch self {
            case .csv:  return "tablecells"
            case .json: return "curlybraces"
            }
        }
    }

    // MARK: - 状態

    var isPickerPresented: Bool = false
    var isExporterPresented: Bool = false
    var isAlertPresented: Bool = false
    var alertMessage: String?
    var pickerKind: PickerKind = .csv
    var isWorking: Bool = false
    var lastResult: String?
    var exportDocument: HistoryCSVDocument?

    // MARK: - 起動

    func beginImport(kind: PickerKind) {
        pickerKind = kind
        isPickerPresented = true
    }

    func showProPaywall(for feature: ProFeature) {
        // Paywall 画面の本実装は P5 IAP フェーズ。ここではエラーで意思表示する。
        let signal = AppError.proRequired(feature)
        alertMessage = signal.errorDescription
        isAlertPresented = true
    }

    func presentError(_ error: Error) {
        let normalized = (error as? AppError) ?? AppError.importFailed(reason: String(describing: error))
        alertMessage = normalized.errorDescription
        isAlertPresented = true
    }

    // MARK: - Import

    func runImport(url: URL, modelContext: ModelContext) throws {
        isWorking = true
        defer { isWorking = false }

        // Files.app 経由で来た URL はサンドボックス外。security-scoped access が必要。
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)

        switch pickerKind {
        case .csv:
            let result = try CSVImporter.importExercises(from: data, into: modelContext)
            lastResult = String(
                localized: "data-io.result.csv",
                defaultValue: "CSV: 追加 \(result.inserted) / 更新 \(result.updated) / スキップ \(result.skipped)"
            )
        case .json:
            let result = try JSONImporter.importAll(from: data, into: modelContext)
            lastResult = String(
                localized: "data-io.result.json",
                defaultValue: "JSON: 種目 +\(result.insertedExercises) ~\(result.updatedExercises) / セッション +\(result.insertedSessions)"
            )
        }
    }

    // MARK: - Export

    func prepareExport(modelContext: ModelContext) throws {
        isWorking = true
        defer { isWorking = false }

        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let sessions = try modelContext.fetch(descriptor)
        let csv = HistoryExporter.exportCSV(sessions)
        exportDocument = HistoryCSVDocument(data: csv)
        isExporterPresented = true
    }

    func handleExportFinished(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            lastResult = String(
                localized: "data-io.result.export",
                defaultValue: "履歴を CSV にエクスポートしました"
            )
        case .failure(let error):
            presentError(error)
        }
        exportDocument = nil
    }
}

// MARK: - HistoryCSVDocument
// .fileExporter に渡す FileDocument。SwiftUI の標準パターン。

struct HistoryCSVDocument: FileDocument, Sendable {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
