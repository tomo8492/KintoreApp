// MARK: - WatchSyncPayload
// v1.1 Watch 単体記録(Phase 2)の iPhone ↔ Apple Watch 間プロトコル契約。
//
// WatchConnectivity は [String: Any] 辞書しか運べないため、型付きペイロードを
// JSONEncoder で Data にして 1 キーに詰める方式で往復させる。
// 本ファイルは WorkoutKit(iOS)と WorkoutKitWatchApp(watchOS)の両ターゲットに
// コンパイルされる唯一の共有定義。ここを変えるときは両側の互換を必ず確認する。
//
// 方向別の輸送手段(設計判断):
//   iPhone → Watch: `updateApplicationContext` — 「最新の状態」だけあれば良い
//                    (よく使う種目リスト)。上書き型で再送不要。
//   Watch → iPhone: `transferUserInfo` — 記録セットは 1 件も落とせないため
//                    到達保証付きキューを使う。オフライン中も watchOS 側で保留される。

import Foundation

/// iPhone → Watch: クイック記録の候補に出す「最近使った種目」。
/// Watch 側は SwiftData を持たないため、表示名を両言語とも同梱して自己完結させる。
struct WatchRecentExercise: Codable, Identifiable, Hashable, Sendable {
    let slug: String
    let nameJa: String
    let nameEn: String
    /// 前回この種目で使った重量(kg)。Watch 側の初期値に使う。未記録は nil。
    let lastWeightKg: Double?
    /// 前回のレップ数。未記録は nil。
    let lastReps: Int?

    var id: String { slug }
}

/// Watch → iPhone: Watch 上で記録された 1 セット。
/// iPhone 側は受信したら「Watch クイックログ」として当日の WorkoutSession に取り込む。
struct WatchLoggedSet: Codable, Identifiable, Hashable, Sendable {
    /// 冪等キー。transferUserInfo の再送・重複配信をこの id で弾く。
    let id: UUID
    let slug: String
    let reps: Int
    let weightKg: Double
    let loggedAt: Date
}

/// WatchConnectivity 辞書のキー名。文字列 typo をコンパイル時に防ぐ。
enum WatchSyncKey {
    /// applicationContext: `Data`(`[WatchRecentExercise]` の JSON)
    static let recentExercises = "wk.recentExercises.v1"
    /// transferUserInfo: `Data`(`[WatchLoggedSet]` の JSON)
    static let loggedSets = "wk.loggedSets.v1"
}

/// エンコード/デコードの共通ヘルパ。日付は ISO8601 固定で両 OS 差異を排除する。
enum WatchSyncCoder {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}
