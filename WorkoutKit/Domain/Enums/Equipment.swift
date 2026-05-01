// MARK: - Equipment
// workout-cool の `EQUIPMENT` 属性値に対応(CLAUDE.md §4.2)。
// Builder の器具選択(F-01)と Generator の Predicate フィルタで使う。

import Foundation

enum Equipment: String, Codable, CaseIterable, Sendable {
    case bodyweight
    case dumbbell
    case barbell
    case kettlebell
    case machine
    case cable
    case band
    case pullupBar
    case bench
    case trx
    case foamRoller
    case yogaMat
}
