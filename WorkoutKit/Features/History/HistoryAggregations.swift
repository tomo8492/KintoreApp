// MARK: - HistoryAggregations
// HistoryChartsView 用の集計値型。Charts 層に依存させないために本ファイルに分離する。
// 計算は in-memory で行う。同梱データ量(年間最大数千セット想定)では十分高速。

import Foundation

// MARK: - WeeklyVolumePoint

/// 週始まり × 部位グループ単位のボリューム。Chart で stack 表示する。
struct WeeklyVolumePoint: Identifiable {
    let id = UUID()
    let weekStart: Date
    let muscleGroup: Muscle.Group
    let volumeKg: Double

    /// セット集合を「週始まり × 部位グループ」で集計する。
    /// Calendar.current.firstWeekday を尊重する。
    static func aggregate(sessions: [WorkoutSession]) -> [WeeklyVolumePoint] {
        let calendar = Calendar.current
        var bucket: [Date: [Muscle.Group: Double]] = [:]

        for session in sessions {
            for set in session.sets {
                let weight = Double(set.reps) * set.weightKg
                guard weight > 0 else { continue }
                guard let exercise = set.exercise else { continue }
                let week = weekStart(for: set.completedAt ?? session.startedAt, calendar: calendar)
                let group = exercise.primaryMuscle.group
                bucket[week, default: [:]][group, default: 0] += weight
            }
        }

        return bucket
            .flatMap { (week, groups) in
                groups.map { WeeklyVolumePoint(weekStart: week, muscleGroup: $0.key, volumeKg: $0.value) }
            }
            .sorted { lhs, rhs in
                if lhs.weekStart != rhs.weekStart { return lhs.weekStart < rhs.weekStart }
                return lhs.muscleGroup.rawValue < rhs.muscleGroup.rawValue
            }
    }

    private static func weekStart(for date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }
}

// MARK: - MonthlyVolumePoint (Pro)

/// 月単位の総ボリューム推移。詳細チャート(advancedCharts)用。
struct MonthlyVolumePoint: Identifiable {
    let id = UUID()
    let monthStart: Date
    let volumeKg: Double

    static func aggregate(sessions: [WorkoutSession]) -> [MonthlyVolumePoint] {
        let calendar = Calendar.current
        var bucket: [Date: Double] = [:]
        for session in sessions {
            for set in session.sets {
                let weight = Double(set.reps) * set.weightKg
                guard weight > 0 else { continue }
                let month = monthStart(for: set.completedAt ?? session.startedAt, calendar: calendar)
                bucket[month, default: 0] += weight
            }
        }
        return bucket
            .map { MonthlyVolumePoint(monthStart: $0.key, volumeKg: $0.value) }
            .sorted { $0.monthStart < $1.monthStart }
    }

    private static func monthStart(for date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }
}

// MARK: - MuscleHeatmapMatrix (Pro)

/// 週 × 部位 のヒートマップ用 2 次元集計。詳細チャート(advancedCharts)用。
struct MuscleHeatmapMatrix {
    let cells: [Cell]

    struct Cell: Identifiable {
        let id = UUID()
        let weekStart: Date
        let muscle: Muscle
        let volumeKg: Double
    }

    static func aggregate(sessions: [WorkoutSession]) -> MuscleHeatmapMatrix {
        let calendar = Calendar.current
        var bucket: [Date: [Muscle: Double]] = [:]

        for session in sessions {
            for set in session.sets {
                let weight = Double(set.reps) * set.weightKg
                guard weight > 0 else { continue }
                guard let exercise = set.exercise else { continue }
                let week = weekStart(for: set.completedAt ?? session.startedAt, calendar: calendar)
                bucket[week, default: [:]][exercise.primaryMuscle, default: 0] += weight
            }
        }

        let cells: [Cell] = bucket.flatMap { (week, muscleMap) in
            muscleMap.map { Cell(weekStart: week, muscle: $0.key, volumeKg: $0.value) }
        }
        return MuscleHeatmapMatrix(cells: cells)
    }

    private static func weekStart(for date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }
}

// MARK: - Muscle.Group localization

extension Muscle.Group {
    /// チャート凡例で使う表示名。String Catalog に同 key を持たせる。
    var localizedTitle: String {
        switch self {
        case .upperBody: return String(localized: "muscle.group.upper", defaultValue: "上半身")
        case .core:      return String(localized: "muscle.group.core", defaultValue: "体幹")
        case .lowerBody: return String(localized: "muscle.group.lower", defaultValue: "下半身")
        case .fullBody:  return String(localized: "muscle.group.full", defaultValue: "全身")
        }
    }
}
