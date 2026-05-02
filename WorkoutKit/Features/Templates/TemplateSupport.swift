// MARK: - TemplateSupport
// CLAUDE.md §1.1 F-05 / §11.4 準拠。
// Templates 機能で使う小さな型・ローカライズ補助・Identifiable 適合をまとめる。
// View 本体を 300 行以下に保つための分割ファイル(§11.4 のファイル分割規約)。

import Foundation
import SwiftUI
import SwiftData

// MARK: - PendingUse

/// `pendingUseOutput` Binding 用に Identifiable を満たす軽量ラッパ。
/// 「使う」タップで GeneratorOutput をプレビュー sheet に詰めて返す。
struct PendingUse: Identifiable {
    let id = UUID()
    let output: GeneratorOutput
    let displayName: String
}

// MARK: - TemplateNaming

/// プリセット名(英語安定識別子)を Localizable.xcstrings 経由の表示名に変換する。
/// マッチしない場合(ユーザー作成の任意名)はそのまま返す。
enum TemplateNaming {
    static func localizedDisplayName(for template: Template) -> String {
        switch template.name {
        case "Push Day (PPL)":
            return String(localized: "templates.preset.pushDay")
        case "Lower Body (Upper/Lower)":
            return String(localized: "templates.preset.lowerBody")
        case "Full Body":
            return String(localized: "templates.preset.fullBody")
        default:
            return template.name
        }
    }

    /// 一覧表示用の補助行。例: "全身  ・ 増量  ・ 3 種目"
    static func subtitle(for template: Template) -> String {
        let goalText = GoalLabels.displayName(for: template.defaultGoal)
        let count = template.exerciseSlugs.count
        let unit = String(localized: "templates.exerciseCountUnit")
        return "\(goalText) ・ \(count) \(unit)"
    }

    /// 「複製」アクション用の新名称(例: "Full Body" → "Full Body (Copy)")。
    static func duplicateName(for original: String) -> String {
        let suffix = String(localized: "templates.duplicate.suffix")
        return "\(original) \(suffix)"
    }
}

// MARK: - GoalLabels

/// Goal の表示用ラベル。Localizable.xcstrings 経由で日英を出し分け。
enum GoalLabels {
    static func displayName(for goal: Goal) -> String {
        switch goal {
        case .hypertrophy: return String(localized: "goal.hypertrophy")
        case .fatLoss:     return String(localized: "goal.fatLoss")
        case .endurance:   return String(localized: "goal.endurance")
        case .flexibility: return String(localized: "goal.flexibility")
        case .cardio:      return String(localized: "goal.cardio")
        }
    }
}

// MARK: - ProFeature Identifiable bridge

extension ProFeature: Identifiable {
    public var id: String { rawValue }
}
