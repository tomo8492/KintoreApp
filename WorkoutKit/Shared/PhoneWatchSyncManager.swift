// MARK: - PhoneWatchSyncManager
// v1.1 Watch quick-log (Phase 2-2) — iPhone 側の WatchConnectivity ラッパー。
// CLAUDE.md §11 準拠: `.shared` シングルトンを新規に作らない(AppDependency 経由 DI)。
//
// プロトコル契約は `WatchSyncPayload.swift`(WatchRecentExercise / WatchLoggedSet /
// WatchSyncKey / WatchSyncCoder)で凍結済み。本ファイルは輸送層のみを担当する。
//
// 方向別の輸送手段(WatchSyncPayload.swift のコメント参照):
//   iPhone → Watch: `updateApplicationContext`(最新の「最近使った種目」で上書き)
//   Watch → iPhone: `didReceiveUserInfo`(到達保証付きキュー、1件も落とさない)
//
// 設計:
//   - `@MainActor final class ... NSObject, WCSessionDelegate`。
//     RestTimerManager / LiveActivityClient と同じ「nonisolated init」パターンで
//     AppDependency.defaultValue(nonisolated context)から構築できるようにする。
//     ただし `.shared` static は持たない(AppDependency のフィールドとして注入)。
//   - WCSessionDelegate のコールバックは OS が任意スレッドから叩くため、
//     各メソッドを `nonisolated` にして Swift 6 concurrency を満たし、
//     MainActor 状態(`onReceiveLoggedSets` 呼び出し)へは `Task { @MainActor in }` で
//     ホップする。
//   - watchOS 側 target が別ワーカー管理のため、本ファイルは
//     `#if canImport(WatchConnectivity)` で守りつつ、シミュレータ /
//     WatchConnectivity 不在ビルドでも型自体は解決できるよう空スタブを用意する。

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
import Foundation
import OSLog

private let watchSyncLogger = Logger(subsystem: "com.tomo.workoutkit", category: "watch-sync")

#if canImport(WatchConnectivity)

@MainActor
final class PhoneWatchSyncManager: NSObject, WCSessionDelegate {

    // MARK: - Bridge

    /// Watch → iPhone: 受信した LoggedSet 群を渡すコールバック。
    /// WorkoutKitApp 側で SwiftData への取り込みロジックを配線する(defaultValue は
    /// nonisolated 評価のためここでは配線しない、AppDependency.swift と同じ注意)。
    var onReceiveLoggedSets: (@MainActor ([WatchLoggedSet]) -> Void)?

    // MARK: - Init

    /// AppDependency.defaultValue(nonisolated context)から構築できるよう nonisolated。
    /// Observable state には触れないので競合なし。
    nonisolated override init() {
        super.init()
    }

    // MARK: - Lifecycle

    /// アプリ起動時に一度だけ呼ぶ(WorkoutKitApp の `.task` から)。
    func activate() {
        guard WCSession.isSupported() else {
            watchSyncLogger.info("WCSession not supported on this device; skipping activate")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        watchSyncLogger.info("WCSession.activate() called")
    }

    // MARK: - Send (iPhone -> Watch)

    /// 「最近使った種目」を Watch に配信する。上書き型(最新状態のみ必要)なので
    /// `updateApplicationContext` を使う。失敗はログのみ、呼び出し元は続行してよい。
    func sendRecentExercises(_ items: [WatchRecentExercise]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            watchSyncLogger.info("sendRecentExercises: session not activated yet, skipping")
            return
        }
        do {
            let data = try WatchSyncCoder.encode(items)
            try session.updateApplicationContext([WatchSyncKey.recentExercises: data])
            watchSyncLogger.info("sendRecentExercises: sent \(items.count, privacy: .public) items")
        } catch {
            watchSyncLogger.error("sendRecentExercises failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            watchSyncLogger.error("activationDidComplete error: \(error.localizedDescription, privacy: .public)")
        } else {
            watchSyncLogger.info("activationDidComplete: state=\(activationState.rawValue, privacy: .public)")
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        watchSyncLogger.info("sessionDidBecomeInactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        watchSyncLogger.info("sessionDidDeactivate; reactivating for watch switch")
        // Apple 推奨: 複数 Watch ペアリング切替に対応するため再アクティベートする。
        session.activate()
    }

    /// Watch → iPhone: `transferUserInfo` の到達保証キューから届く。
    /// 冪等化(重複配信の除去)は受け手側(WorkoutKitApp の ingest)で id ベースに行う。
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo[WatchSyncKey.loggedSets] as? Data else { return }
        do {
            let sets = try WatchSyncCoder.decode([WatchLoggedSet].self, from: data)
            Task { @MainActor [weak self] in
                self?.onReceiveLoggedSets?(sets)
            }
        } catch {
            watchSyncLogger.error("didReceiveUserInfo decode failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#else

// MARK: - Stub (WatchConnectivity 不在ビルド用)
// 実機/シミュレータの通常ビルドでは到達しないが、WatchConnectivity が
// canImport できない環境(例: 一部 CI ターゲット)でもコンパイルを通すための空実装。

@MainActor
final class PhoneWatchSyncManager {
    var onReceiveLoggedSets: (@MainActor ([WatchLoggedSet]) -> Void)?

    nonisolated init() {}

    func activate() {
        watchSyncLogger.info("WatchConnectivity unavailable in this build; no-op")
    }

    func sendRecentExercises(_ items: [WatchRecentExercise]) {
        watchSyncLogger.info("WatchConnectivity unavailable in this build; sendRecentExercises no-op")
    }
}

#endif
