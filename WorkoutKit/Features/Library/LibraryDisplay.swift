// MARK: - LibraryDisplay
// 種目DB UI(F-02)で共有する表示用ヘルパー。
// enum の rawValue は workout-cool 互換の英語固定なので、
// 表示文字列・SF Symbol マッピングをここで一元化する。

import Foundation
import SwiftUI

enum LibraryDisplay {
    // MARK: - Muscle

    static func muscleName(_ muscle: Muscle) -> LocalizedStringKey {
        switch muscle {
        case .chest:       return "muscle.chest"
        case .lats:        return "muscle.lats"
        case .traps:       return "muscle.traps"
        case .deltoids:    return "muscle.deltoids"
        case .biceps:      return "muscle.biceps"
        case .triceps:     return "muscle.triceps"
        case .forearms:    return "muscle.forearms"
        case .abs:         return "muscle.abs"
        case .obliques:    return "muscle.obliques"
        case .lowerBack:   return "muscle.lowerBack"
        case .quadriceps:  return "muscle.quadriceps"
        case .hamstrings:  return "muscle.hamstrings"
        case .glutes:      return "muscle.glutes"
        case .calves:      return "muscle.calves"
        case .fullBody:    return "muscle.fullBody"
        }
    }

    // MARK: - Equipment

    static func equipmentName(_ eq: Equipment) -> LocalizedStringKey {
        switch eq {
        case .bodyweight:  return "equipment.bodyweight"
        case .dumbbell:    return "equipment.dumbbell"
        case .barbell:     return "equipment.barbell"
        case .kettlebell:  return "equipment.kettlebell"
        case .machine:     return "equipment.machine"
        case .cable:       return "equipment.cable"
        case .band:        return "equipment.band"
        case .pullupBar:   return "equipment.pullupBar"
        case .bench:       return "equipment.bench"
        case .trx:         return "equipment.trx"
        case .foamRoller:  return "equipment.foamRoller"
        case .yogaMat:     return "equipment.yogaMat"
        }
    }

    /// 器具の SF Symbol。専用シンボルが無いものは figure 系にフォールバック。
    static func equipmentSymbol(_ eq: Equipment) -> String {
        switch eq {
        case .bodyweight: return "figure.walk"
        case .dumbbell:   return "dumbbell.fill"
        case .barbell:    return "figure.strengthtraining.traditional"
        case .kettlebell: return "scalemass.fill"
        case .machine:    return "gearshape.2.fill"
        case .cable:      return "cable.connector"
        case .band:       return "circle.dashed"
        // figure.pull.up は iOS 26 で消えていてレンダーされないため、
        // 安全な代替に置換する(EquipmentStepView と同じグリフに統一)。
        case .pullupBar:  return "figure.strengthtraining.functional"
        case .bench:      return "rectangle.fill"
        case .trx:        return "link"
        case .foamRoller: return "cylinder.fill"
        case .yogaMat:    return "figure.yoga"
        }
    }

    // MARK: - Type / Mechanics

    static func typeName(_ t: ExerciseType) -> LocalizedStringKey {
        switch t {
        case .strength:     return "type.strength"
        case .cardio:       return "type.cardio"
        case .stretching:   return "type.stretching"
        case .calisthenics: return "type.calisthenics"
        case .warmup:       return "type.warmup"
        case .plyometrics:  return "type.plyometrics"
        }
    }

    static func mechanicsName(_ m: MechanicsType) -> LocalizedStringKey {
        switch m {
        case .compound:  return "mechanics.compound"
        case .isolation: return "mechanics.isolation"
        }
    }
}

// MARK: - Display name helpers (overloads for filterPicker)
// LocalizedStringKey は SwiftUI Text 用。Picker のラベルでも使えるよう
// String を返す版も提供する(VoiceOver / accessibilityLabel 用)。

extension LibraryDisplay {
    static func muscleDisplayKey(_ m: Muscle) -> LocalizedStringKey { muscleName(m) }
    static func equipmentDisplayKey(_ e: Equipment) -> LocalizedStringKey { equipmentName(e) }
    static func typeDisplayKey(_ t: ExerciseType) -> LocalizedStringKey { typeName(t) }
    static func mechanicsDisplayKey(_ m: MechanicsType) -> LocalizedStringKey { mechanicsName(m) }
}

// MARK: - Step illustrations (Phase 2-1 infra)
// Exercise.stepImagesRaw は JSON 文字列配列("[]" がデフォルト、345 種目すべて未投入)。
// StepsCardView がアセットカタログ照会前に使う純粋なデコードヘルパーをここに置く。
// 破損 JSON でもクラッシュしないよう try? でフォールバックする(NG リスト: try! 禁止)。

extension LibraryDisplay {
    /// `exercise.stepImagesRaw` をデコードして画像名の配列を返す。
    /// デコード失敗・空文字は空配列にフォールバックする。
    static func stepImageNames(for exercise: Exercise) -> [String] {
        guard let data = exercise.stepImagesRaw.data(using: .utf8),
              let names = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return names
    }
}
