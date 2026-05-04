// MARK: - Goal
// Builder ウィザード(F-01)の最初のステップで選ぶ「目的」。
// Generator はこれを見て compound / isolation の比率や warmup/cooldown の重みを決める。

import Foundation

enum Goal: String, Codable, CaseIterable, Sendable {
    case hypertrophy = "hypertrophy"   // 筋肥大
    case fatLoss     = "fat-loss"      // 減量
    case endurance   = "endurance"     // 筋持久力
    case flexibility = "flexibility"   // 柔軟性
    case cardio      = "cardio"        // 心肺機能
}

extension Goal {
    /// メインパートにおける compound 種目の比率(0.0〜1.0)。
    /// CLAUDE.md §4.3 の擬似コードに合わせる。
    var compoundRatio: Double {
        switch self {
        case .hypertrophy: return 0.6
        case .fatLoss:     return 0.7
        case .endurance:   return 0.4
        case .flexibility: return 0.0  // メインパートを持たない
        case .cardio:      return 0.0  // CARDIO 種目を優先
        }
    }
}
