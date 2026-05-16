// MARK: - TemplateStore
// CLAUDE.md §1.1 F-05 / §4.1 準拠。
// Template モデルへの CRUD を集約する @Observable ストア。
//
// 規約:
// - @MainActor 隔離(SwiftUI View から直接バインドできるように)
// - Pro ゲートはここでは判定しない。呼び出し側の View が
//   ProFeatureGate.check(.customTemplates) を見てから create/update/delete を呼ぶ。
//   これにより「失敗→Paywall表示」の責務が UI 側に集まる(§-1.14 のトリガー仕様)。
// - print 禁止、強制アンラップ禁止、Singleton 禁止(§11.4)
// - エラーは throws で投げ、UI 側で AppError へ正規化する。

import Foundation
import SwiftData
import Observation
import OSLog

@Observable
@MainActor
final class TemplateStore {
    // MARK: - State

    /// 表示用に並べ替え済みのテンプレ一覧。プリセット → ユーザー作成、
    /// 各グループ内では作成日時昇順。
    private(set) var templates: [Template] = []

    // MARK: - Dependencies

    private let context: ModelContext

    // MARK: - Init

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Read

    /// SwiftData から再フェッチして `templates` を更新する。
    /// 失敗時は空配列にして Logger に残す(UI を壊さない)。
    /// 並び順: プリセット → ユーザー作成、各グループ内で createdAt 昇順。
    /// (SwiftData の SortDescriptor は Bool を扱えないため、フェッチ後に
    /// メモリ上で安定ソートする。)
    func reload() {
        // NOTE: KeyPath<Template, Date> の非 Sendable 警告は SwiftData @Model
        // が Sendable 適合できない SDK 側の問題で個別対処不可。Apple 修正待ち。
        let descriptor = FetchDescriptor<Template>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        do {
            let fetched = try context.fetch(descriptor)
            templates = fetched.sorted { lhs, rhs in
                if lhs.isUserCreated != rhs.isUserCreated {
                    return !lhs.isUserCreated  // preset(false)を先に
                }
                return lhs.createdAt < rhs.createdAt
            }
        } catch {
            Logger.data.error("TemplateStore.reload failed: \(error.localizedDescription, privacy: .public)")
            templates = []
        }
    }

    // MARK: - Create (Pro)

    /// 新規テンプレート作成。`isUserCreated = true` 固定。
    /// Pro ゲートは呼び出し側でチェック済みである前提。
    @discardableResult
    func create(name: String, exerciseSlugs: [String], goal: Goal) throws -> Template {
        let raw = try Self.encodeSlugs(exerciseSlugs)
        let template = Template(
            name: name,
            exerciseSlugsRaw: raw,
            defaultGoalRaw: goal.rawValue,
            isUserCreated: true
        )
        context.insert(template)
        try context.save()
        Logger.data.info("template created: name=\(name, privacy: .public), slugs=\(exerciseSlugs.count)")
        reload()
        return template
    }

    // MARK: - Duplicate (Free)

    /// 既存テンプレ(プリセット含む)を複製する。複製は常に user-created。
    /// 複製は Free 機能(プリセットを少しいじりたい人の入口を塞がない)。
    @discardableResult
    func duplicate(_ template: Template, newName: String) throws -> Template {
        let copy = Template(
            name: newName,
            exerciseSlugsRaw: template.exerciseSlugsRaw,
            defaultGoalRaw: template.defaultGoalRaw,
            isUserCreated: true
        )
        context.insert(copy)
        try context.save()
        Logger.data.info("template duplicated: from=\(template.name, privacy: .public), to=\(newName, privacy: .public)")
        reload()
        return copy
    }

    // MARK: - Update (Pro)

    /// 部分更新。nil のフィールドは触らない。
    /// Pro ゲートは呼び出し側でチェック済みである前提。
    func update(
        _ template: Template,
        name: String? = nil,
        exerciseSlugs: [String]? = nil,
        goal: Goal? = nil
    ) throws {
        if let name { template.name = name }
        if let slugs = exerciseSlugs {
            template.exerciseSlugsRaw = try Self.encodeSlugs(slugs)
        }
        if let goal { template.defaultGoalRaw = goal.rawValue }
        try context.save()
        reload()
    }

    // MARK: - Delete (Pro)

    /// テンプレを削除する。プリセット削除も許容(Pro 限定 UI から呼ばれる)。
    /// プリセットを消した場合 TemplateSeeder は再実行されない(seed フラグは UserDefaults で管理)。
    func delete(_ template: Template) throws {
        let name = template.name
        context.delete(template)
        try context.save()
        Logger.data.info("template deleted: name=\(name, privacy: .public)")
        reload()
    }

    // MARK: - Use → Generator Output

    /// 「使う」アクション用。Template から GeneratorOutput を組み立てて返す。
    /// SessionStore(B2 で実装予定)はこれを受け取って実行画面を起動する。
    /// 現状はメインパートのみを埋め、warmup/cooldown は空(Builder が決める)。
    func makeGeneratorOutput(from template: Template) -> GeneratorOutput {
        GeneratorOutput(
            warmup: [],
            main: template.exerciseSlugs,
            cooldown: []
        )
    }

    // MARK: - Helpers

    private static func encodeSlugs(_ slugs: [String]) throws -> String {
        let data = try JSONEncoder().encode(slugs)
        guard let string = String(data: data, encoding: .utf8) else {
            throw AppError.dataCorruption("template slug encode failed")
        }
        return string
    }
}
