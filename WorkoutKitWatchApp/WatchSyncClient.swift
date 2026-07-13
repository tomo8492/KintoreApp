// MARK: - WatchSyncClient
// Phase 2-2 (Watch 単体記録) 準拠。
//
// WatchSyncPayload.swift (FROZEN 契約) に従って WCSession をラップする。
//   iPhone → Watch: `updateApplicationContext` で送られる「最近使った種目」を
//     session(_:didReceiveApplicationContext:) で受け取りデコードして公開する。
//     アプリ再起動をまたいでも一覧が空にならないよう、受信のたびに
//     UserDefaults へキャッシュし、起動直後はそのキャッシュから復元する。
//   Watch → iPhone: `transferUserInfo` で記録したセットを送る。到達保証付き
//     キューのため、オフライン中に記録しても watchOS 側で保留され、
//     再接続時に自動送信される。
//
// Swift 6 concurrency: WCSessionDelegate のコールバックは任意スレッドから
// 呼ばれるため nonisolated で受け、@MainActor 側の状態更新は Task で hop する。
// 本クラスは @MainActor final class なので暗黙的に Sendable。

import Foundation
import Observation
import WatchConnectivity

@MainActor
@Observable
final class WatchSyncClient: NSObject {
    static let shared = WatchSyncClient()

    private(set) var recentExercises: [WatchRecentExercise] = []

    /// WCSession 経由で受信した最新スナップショットのローカルキャッシュキー。
    /// Watch アプリ再起動直後、iPhone 側からの再送を待たずに一覧を表示するために使う。
    private let cacheKey = "wk.watch.recentExercises.cache.v1"

    private let session: WCSession?

    override init() {
        self.session = WCSession.isSupported() ? WCSession.default : nil
        super.init()
        loadCachedExercises()
    }

    /// WCSession を有効化する。アプリ起動時に一度だけ呼ぶ。
    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Watch 上で記録した 1 セットを iPhone へ送る(到達保証付きキュー)。
    func log(_ set: WatchLoggedSet) {
        guard let session else { return }
        do {
            let data = try WatchSyncCoder.encode([set])
            session.transferUserInfo([WatchSyncKey.loggedSets: data])
        } catch {
            // WatchLoggedSet は単純な Codable 値型なのでエンコード失敗は
            // 実質起こり得ない。クラッシュさせず黙って諦める。
        }
    }

    // MARK: - Cache

    private func loadCachedExercises() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? WatchSyncCoder.decode([WatchRecentExercise].self, from: data)
        else { return }
        recentExercises = decoded
    }

    private func cacheExercises(_ exercises: [WatchRecentExercise]) {
        guard let data = try? WatchSyncCoder.encode(exercises) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    fileprivate func applyReceivedContext(_ context: [String: Any]) {
        guard let data = context[WatchSyncKey.recentExercises] as? Data,
              let decoded = try? WatchSyncCoder.decode([WatchRecentExercise].self, from: data)
        else { return }
        recentExercises = decoded
        cacheExercises(decoded)
    }
}

// MARK: - WCSessionDelegate

extension WatchSyncClient: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated, error == nil else { return }
        // 有効化完了時点で最新の applicationContext を取り込む(遅延受信対策)。
        let context = session.receivedApplicationContext
        Task { @MainActor [weak self] in
            self?.applyReceivedContext(context)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor [weak self] in
            self?.applyReceivedContext(applicationContext)
        }
    }
}
