// MARK: - Muscle
// workout-cool の `PRIMARY_MUSCLE` / `SECONDARY_MUSCLE` 属性値に対応(CLAUDE.md §4.2)。
// rawValue はlowerCamelCaseで保持し、CSVの大文字値は parser 側で正規化して取り込む。

import Foundation

enum Muscle: String, Codable, CaseIterable, Sendable {
    // 上半身
    case chest
    case lats
    case traps
    case deltoids
    case biceps
    case triceps
    case forearms

    // 体幹
    case abs
    case obliques
    case lowerBack

    // 下半身
    case quadriceps
    case hamstrings
    case glutes
    case calves

    // 全身
    case fullBody
}

extension Muscle {
    /// Builder の部位選択UI(F-01)で表示する大分類グループ。
    enum Group: String, CaseIterable, Sendable {
        case upperBody, core, lowerBody, fullBody
    }

    var group: Group {
        switch self {
        case .chest, .lats, .traps, .deltoids, .biceps, .triceps, .forearms:
            return .upperBody
        case .abs, .obliques, .lowerBack:
            return .core
        case .quadriceps, .hamstrings, .glutes, .calves:
            return .lowerBody
        case .fullBody:
            return .fullBody
        }
    }
}
