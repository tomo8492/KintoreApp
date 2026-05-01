// MARK: - AttributeNormalizer
// workout-cool CSV の attribute_value(SNAKE_CASE)を WorkoutKit の enum rawValue に正規化する。
// CLAUDE.md §4.2 / §-1.2 規約により Muscle / Equipment は lowerCamelCase で保持しているため、
// 文字列マッピングはここに集約しておき、enum 側は触らない。

import Foundation

enum AttributeNormalizer {

    // MARK: - ExerciseType

    static func exerciseType(_ raw: String) -> String? {
        let key = raw.uppercased()
        switch key {
        case "STRENGTH":     return ExerciseType.strength.rawValue
        case "CARDIO":       return ExerciseType.cardio.rawValue
        case "STRETCHING",
             "STRETCH":      return ExerciseType.stretching.rawValue
        case "CALISTHENICS",
             "CALISTHENIC": return ExerciseType.calisthenics.rawValue
        case "WARMUP",
             "WARM_UP",
             "WARM-UP":      return ExerciseType.warmup.rawValue
        case "PLYOMETRICS",
             "PLYOMETRIC":  return ExerciseType.plyometrics.rawValue
        default:
            // ExerciseType の rawValue と直接一致するケース(将来拡張用)
            return ExerciseType(rawValue: key).map(\.rawValue)
        }
    }

    // MARK: - MechanicsType

    static func mechanicsType(_ raw: String) -> String? {
        let key = raw.uppercased()
        return MechanicsType(rawValue: key).map(\.rawValue)
    }

    // MARK: - Muscle

    static func muscle(_ raw: String) -> String? {
        let key = raw.uppercased()
        switch key {
        case "CHEST", "PECTORALS":            return Muscle.chest.rawValue
        case "BACK", "LATS", "LATISSIMUS":    return Muscle.lats.rawValue
        case "TRAPS", "TRAPEZIUS":            return Muscle.traps.rawValue
        case "SHOULDERS", "DELTOIDS",
             "DELTS":                         return Muscle.deltoids.rawValue
        case "BICEPS":                        return Muscle.biceps.rawValue
        case "TRICEPS":                       return Muscle.triceps.rawValue
        case "FOREARMS", "FOREARM":           return Muscle.forearms.rawValue
        case "ABS", "ABDOMINALS":             return Muscle.abs.rawValue
        case "OBLIQUES":                      return Muscle.obliques.rawValue
        case "LOWER_BACK", "LOWERBACK",
             "LOW_BACK":                      return Muscle.lowerBack.rawValue
        case "QUADRICEPS", "QUADS":           return Muscle.quadriceps.rawValue
        case "HAMSTRINGS":                    return Muscle.hamstrings.rawValue
        case "GLUTES", "GLUTEUS":             return Muscle.glutes.rawValue
        case "CALVES":                        return Muscle.calves.rawValue
        case "FULL_BODY", "FULLBODY",
             "BODY":                          return Muscle.fullBody.rawValue
        default:
            // 既に lowerCamelCase で来た場合(JSON Importer 共通利用)
            return Muscle(rawValue: raw).map(\.rawValue)
        }
    }

    // MARK: - Equipment

    static func equipment(_ raw: String) -> String? {
        let key = raw.uppercased()
        switch key {
        case "BODY_ONLY", "BODYWEIGHT",
             "NONE":                          return Equipment.bodyweight.rawValue
        case "DUMBBELL":                      return Equipment.dumbbell.rawValue
        case "BARBELL":                       return Equipment.barbell.rawValue
        case "KETTLEBELL", "KETTLEBELLS":     return Equipment.kettlebell.rawValue
        case "MACHINE":                       return Equipment.machine.rawValue
        case "CABLE":                         return Equipment.cable.rawValue
        case "BAND", "BANDS":                 return Equipment.band.rawValue
        case "PULLUP_BAR", "PULL_UP_BAR",
             "PULLUPBAR":                     return Equipment.pullupBar.rawValue
        case "BENCH":                         return Equipment.bench.rawValue
        case "TRX", "SUSPENSION":             return Equipment.trx.rawValue
        case "FOAM_ROLLER", "FOAMROLLER":     return Equipment.foamRoller.rawValue
        case "YOGA_MAT", "MAT", "YOGAMAT":    return Equipment.yogaMat.rawValue
        default:
            return Equipment(rawValue: raw).map(\.rawValue)
        }
    }
}
