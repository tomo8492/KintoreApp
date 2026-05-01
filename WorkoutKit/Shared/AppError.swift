// MARK: - AppError
// CLAUDE.md §-1.6 規約。
// throws される下位例外は UI 層に届く前にこの enum に正規化する。
// errorDescription は String Catalog (Localizable.xcstrings) から引く。

import Foundation

enum AppError: LocalizedError {
    /// SwiftData の整合性が壊れた(必須リレーション欠損、列挙値の不正等)。
    case dataCorruption(String)
    /// CSV / JSON インポートの失敗。理由文字列はログにのみ書き、UI には汎用文を出す。
    case importFailed(reason: String)
    /// Generator の入力条件にマッチする種目が0件。Builder UI で代替提案を出す。
    case generatorEmpty(GeneratorInputSummary)
    /// 種目に紐づくステップ画像 / 動画が見つからない。
    case mediaMissing(slug: String)
    /// StoreKit の購入フローが失敗(キャンセル除く)。
    case purchaseFailed(String)
    /// Pro 機能が必要だが未購入。Paywall を提示するシグナル。
    case proRequired(ProFeature)

    var errorDescription: String? {
        switch self {
        case .dataCorruption:
            return String(localized: "error.data.corruption", defaultValue: "データに問題が発生しました")
        case .importFailed:
            return String(localized: "error.import.failed", defaultValue: "インポートに失敗しました")
        case .generatorEmpty:
            return String(localized: "error.generator.empty", defaultValue: "条件に合う種目が見つかりませんでした")
        case .mediaMissing:
            return String(localized: "error.media.missing", defaultValue: "ステップ画像が見つかりませんでした")
        case .purchaseFailed:
            return String(localized: "error.purchase.failed", defaultValue: "購入処理に失敗しました")
        case .proRequired:
            return String(localized: "error.pro.required", defaultValue: "この機能は Pro で利用できます")
        }
    }
}

/// AppError.generatorEmpty が抱える入力サマリ。
/// 実際の `GeneratorInput` は SwiftData / Service 層に閉じておきたいので
/// エラーには表示用の最小値だけを持たせる。
struct GeneratorInputSummary: Sendable, Equatable {
    let goalRaw: String
    let muscleCount: Int
    let equipmentCount: Int
    let minutesAvailable: Int
}
