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
    /// 「Pro 機能のため購入が必要」を伝えるシート用 binding。
    /// View 側は `.sheet(item:)` で `PaywallView(reason:)` を提示する。
    /// 旧実装では alert メッセージで意思表示していたが、購入導線が
    /// 無いため Pro 機能を解放する経路が断たれていた(post-purchase
    /// verification で発見した既知の defect)。
    var paywallFeature: ProFeature?

    // MARK: - 起動

    func beginImport(kind: PickerKind) {
        pickerKind = kind
        isPickerPresented = true
    }

    func showProPaywall(for feature: ProFeature) {
        // P5 IAP の本実装(PaywallView)を提示する。
        // 旧実装は alert で「Pro が必要」と知らせるだけで購入導線が無かった。
        paywallFeature = feature
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

        // NOTE: KeyPath<WorkoutSession, Date> の非 Sendable 警告は SwiftData @Model
        // が Sendable 適合できない SDK 側の問題で個別対処不可。Apple 修正待ち。
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
