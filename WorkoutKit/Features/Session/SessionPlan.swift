// MARK: - SessionPlan
// CLAUDE.md §1.1 F-03 / §-1.4 / §11 準拠。
// SessionStore が扱う「これから実施する種目並び」の値型。
// SwiftData モデルを Session 中に複製して持つのではなく、slug + section + 計画セット数
// だけをスナップショットとして保持し、実体は ModelContext から都度引く。
// SceneStorage(JSON 文字列)で復元できるよう Codable とする(§-1.5)。

import Foundation

/// セッション内の1種目分の計画。slug を主キーとして扱うため Identifiable は UUID を持つ。
/// ScrollView の identity に使うため、同一 slug が複数回登場しても並び順を保てるよう
/// インスタンスごとに UUID を発行する。
struct SessionPlanItem: Hashable, Identifiable, Codable, Sendable {
    let id: UUID
    let slug: String
    let section: SessionSection
    /// 計画セット数。warmup/cooldown は 1、main は既定 3。ユーザー入力で増減し得る想定だが
    /// C1 では固定値で開始する。
    var plannedSetCount: Int

    init(
        id: UUID = UUID(),
        slug: String,
        section: SessionSection,
        plannedSetCount: Int
    ) {
        self.id = id
        self.slug = slug
        self.section = section
        self.plannedSetCount = plannedSetCount
    }
}

/// SceneStorage に詰める形のセッション復元情報。
/// - sessionId は SwiftData の WorkoutSession.id を指す。
/// - plan は再生成不能(Generator は乱数を含む)なので別途丸ごと保持する。
struct SessionRestoreSnapshot: Codable, Sendable {
    var sessionId: UUID
    var plan: [SessionPlanItem]
    var currentItemIndex: Int
    var currentSetIndex: Int

    /// JSON 文字列にエンコード。SceneStorage は String/Data 等の primitive のみ受けるため。
    func encoded() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    /// SceneStorage 文字列からデコード。失敗時は nil(空文字や旧形式の場合に備える)。
    static func decoded(from string: String) -> SessionRestoreSnapshot? {
        guard !string.isEmpty,
              let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SessionRestoreSnapshot.self, from: data)
    }
}

extension SessionPlanItem {
    /// section に応じた既定セット数。Generator/Builder からプランを組むときに使う。
    static func defaultSetCount(for section: SessionSection) -> Int {
        switch section {
        case .warmup, .cooldown: return 1
        case .main:              return 3
        }
    }
}

extension Array where Element == SessionPlanItem {
    /// GeneratorOutput の3パートを SessionPlanItem の並びに変換する。
    /// 並びは warmup → main → cooldown で固定(F-01b)。
    static func from(output: GeneratorOutput) -> [SessionPlanItem] {
        var items: [SessionPlanItem] = []
        items.reserveCapacity(output.warmup.count + output.main.count + output.cooldown.count)
        for slug in output.warmup {
            items.append(.init(slug: slug, section: .warmup,
                               plannedSetCount: SessionPlanItem.defaultSetCount(for: .warmup)))
        }
        for slug in output.main {
            items.append(.init(slug: slug, section: .main,
                               plannedSetCount: SessionPlanItem.defaultSetCount(for: .main)))
        }
        for slug in output.cooldown {
            items.append(.init(slug: slug, section: .cooldown,
                               plannedSetCount: SessionPlanItem.defaultSetCount(for: .cooldown)))
        }
        return items
    }
}
