// MARK: - ExerciseType
// workout-cool の attribute_value `TYPE` に対応(CLAUDE.md §4.2)。
// rawValue は workout-cool CSV 互換のため大文字 SNAKE_CASE で固定する。

import Foundation

enum ExerciseType: String, Codable, CaseIterable, Sendable {
    case strength     = "STRENGTH"
    case cardio       = "CARDIO"
    case stretching   = "STRETCHING"
    case calisthenics = "CALISTHENICS"
    case warmup       = "WARMUP"
    case plyometrics  = "PLYOMETRICS"
}

extension ExerciseType {
    /// セッション3部構成(F-01b)におけるどの section に属する種目か。
    /// Builder と Generator はこれを使って warmup / main / cooldown を振り分ける。
    var section: SessionSection {
        switch self {
        case .warmup:     return .warmup
        case .stretching: return .cooldown
        default:          return .main
        }
    }
}

/// セッション内の3部構成区分。WorkoutSession / ExerciseSet の `sectionRaw` と対応。
enum SessionSection: String, Codable, CaseIterable, Sendable {
    case warmup   = "warmup"
    case main     = "main"
    case cooldown = "cooldown"
}
