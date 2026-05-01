// MARK: - MechanicsType
// workout-cool の attribute_value `MECHANICS_TYPE` に対応(CLAUDE.md §4.2)。
// Generator が compound / isolation の比率を goal に応じて調整するために使う。

import Foundation

enum MechanicsType: String, Codable, CaseIterable, Sendable {
    case compound  = "COMPOUND"   // 複合関節(squat, bench press)
    case isolation = "ISOLATION"  // 単関節(curl, leg extension)
}
