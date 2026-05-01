// MARK: - WorkoutGenerator ヘルパー
// マッチ判定 / 並び替え / 乱数取りを WorkoutGenerator から切り出した内部ユーティリティ。
// 全て pure(SwiftData / Logger に触らない)、テスト時にも単体で扱える形を保つ。

import Foundation

extension WorkoutGenerator {

    /// 入力 equipment と種目 equipment の交差判定。
    /// 種目が equipment 指定なし(空)の場合は bodyweight 扱いで bodyweight が許可されていれば true。
    static func matchesEquipment(_ exercise: Exercise, allowed: Set<Equipment>) -> Bool {
        let equip = exercise.equipment
        if equip.isEmpty {
            return allowed.contains(.bodyweight)
        }
        return equip.contains { allowed.contains($0) }
    }

    /// 主働筋 or 協働筋のいずれかが target に含まれるか。
    /// target が空なら常に false(明示的に部位を選んでいない＝対象なし)。
    static func matchesMuscles(_ exercise: Exercise, target: Set<Muscle>) -> Bool {
        guard !target.isEmpty else { return false }
        if target.contains(exercise.primaryMuscle) { return true }
        return exercise.secondaryMuscles.contains { target.contains($0) }
    }

    /// `range` の中から rng で 1 値を引く。available が下限未満ならその数で打ち切る。
    static func randomCount<R: RandomNumberGenerator>(
        in range: ClosedRange<Int>,
        available: Int,
        rng: inout R
    ) -> Int {
        guard available > 0 else { return 0 }
        let lower = range.lowerBound
        let upper = range.upperBound
        if available < lower { return available }
        let span = UInt64(upper - lower + 1)
        let pick = lower + Int(rng.next() % span)
        return min(pick, available)
    }

    /// 同じ primaryMuscle が連続しないように貪欲に並べ替える。
    /// 同票時は muscle.rawValue 昇順で確定的に解決する。
    static func interleaveByMuscle(
        _ exercises: [Exercise],
        startingAfter prev: Muscle?
    ) -> [Exercise] {
        var groups: [Muscle: [Exercise]] = [:]
        for ex in exercises {
            groups[ex.primaryMuscle, default: []].append(ex)
        }
        var result: [Exercise] = []
        var lastMuscle = prev

        while !groups.isEmpty {
            let avoid = lastMuscle
            let candidates = groups.filter { $0.key != avoid }
            let pool = candidates.isEmpty ? groups : candidates
            let sorted = pool.sorted { lhs, rhs in
                if lhs.value.count != rhs.value.count { return lhs.value.count > rhs.value.count }
                return lhs.key.rawValue < rhs.key.rawValue
            }
            let muscle = sorted[0].key
            var arr = groups[muscle] ?? []
            let next = arr.removeFirst()
            if arr.isEmpty {
                groups.removeValue(forKey: muscle)
            } else {
                groups[muscle] = arr
            }
            result.append(next)
            lastMuscle = muscle
        }
        return result
    }
}
