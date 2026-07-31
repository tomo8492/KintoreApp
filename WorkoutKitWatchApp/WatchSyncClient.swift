// MARK: - WatchSyncClient
// Phase 2-2 (Watch 単体記録) 準拠。Audit A1 で todaySummary 中継 / 送信キューを追加。
//
// WatchSyncPayload.swift (FROZEN 契約) に従って WCSession をラップする。
//   iPhone → Watch: `updateApplicationContext` で送られる「最近使った種目」を
//     session(_:didReceiveApplicationContext:) で受け取りデコードして公開する。
//     アプリ再起動をまたいでも一覧が空にならないよう、受信のたびに
//     UserDefaults へキャッシュし、起動直後はそのキャッシュから復元する。
//     同じ applicationContext には「今日のサマリ」(todaySummary)も同梱され得る。
//     App Group はデバイスごとに独立しているため、iPhone 側が書いた
//     WatchSummaryBridge の値は Watch 側には届かない。ここで受け取り次第
//     Watch ローカルの App Group ストアへ書き直し、Smart Stack Widget の
//     タイムラインを再読込する(WorkoutKitWatch/WorkoutWidgetProvider.swift が読む)。
//   Watch → iPhone: `transferUserInfo` で記録したセットを送る。到達保証付き
//     キューのため、オフライン中に記録しても watchOS 側で保留され、
//     再接続時に自動送信される。session 未 activate のうちに呼ばれた分は
//     pendingLoggedSets に積み、activationDidComplete で flush する
//     (transferUserInfo 自体は activate 前でも呼べるが、PhoneWatchSyncManager 側の
//     送信メソッドと挙動を揃えるためここでも明示的に activation を待つ)。
//
// Swift 6 concurrency: WCSessionDelegate のコールバックは任意スレッドから
// 呼ばれるため nonisolated で受け、@MainActor 側の状態更新は Task で hop する。
// `[String: Any]` は Sendable ではないため、Task の @Sendable クロージャに直接
// キャプチャさせず、hop する前に Sendable な `ReceivedContext` へ変換しておく。
// 本クラスは @MainActor final class なので暗黙的に Sendable。

import Foundation
import Observation
import WatchConnectivity
import WidgetKit

@MainActor
@Observable
final class WatchSyncClient: NSObject {
    static let shared = WatchSyncClient()

    /// WorkoutKitWatch/WorkoutKitWatchWidget.swift の `kind` と同一文字列。
    /// Widget Extension とは別 Bundle(別ターゲット)のため定数を import できず、
    /// 文字列を直接ミラーする(値を変えるときは両ファイルを同時に更新すること)。
    private static let widgetKind = "WorkoutKitWatchWidget"

    private(set) var recentExercises: [WatchRecentExercise] = []

    /// WCSession 経由で受信した最新スナップショットのローカルキャッシュキー。
    /// Watch アプリ再起動直後、iPhone 側からの再送を待たずに一覧を表示するために使う。
    private let cacheKey = "wk.watch.recentExercises.cache.v1"

    private let session: WCSession?

    /// session が未 activate のうちに `log(_:)` された分の保留キュー。
    /// activationDidComplete で activated になった時点でまとめて送信する。
    private var pendingLoggedSets: [WatchLoggedSet] = []

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
    /// session が未 activate の場合は送信を保留し、activationDidComplete で flush する。
    func log(_ set: WatchLoggedSet) {
        guard let session else { return }
        guard session.activationState == .activated else {
            pendingLoggedSets.append(set)
            return
        }
        transfer(set)
    }

    private func transfer(_ set: WatchLoggedSet) {
        guard let session else { return }
        do {
            let data = try WatchSyncCoder.encode([set])
            session.transferUserInfo([WatchSyncKey.loggedSets: data])
        } catch {
            // WatchLoggedSet は単純な Codable 値型なのでエンコード失敗は
            // 実質起こり得ない。クラッシュさせず黙って諦める。
        }
    }

    private func flushPendingLoggedSets() {
        guard !pendingLoggedSets.isEmpty else { return }
        let pending = pendingLoggedSets
        pendingLoggedSets.removeAll()
        for set in pending {
            transfer(set)
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

    fileprivate func applyReceivedContext(_ context: ReceivedContext) {
        if let data = context.recentExercisesData,
           let decoded = try? WatchSyncCoder.decode([WatchRecentExercise].self, from: data) {
            recentExercises = decoded
            cacheExercises(decoded)
        }
        if let data = context.todaySummaryData,
           let decoded = try? WatchSyncCoder.decode(TodaySessionSummary.self, from: data) {
            WatchSummaryBridge.write(decoded)
            WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
        }
    }
}

// MARK: - ReceivedContext (Sendable 変換)

/// `session(_:didReceiveApplicationContext:)` / `activationDidCompleteWith` の
/// `[String: Any]` は Sendable ではないため、MainActor へ hop する Task に渡す前に
/// 必要な `Data` だけを取り出した Sendable 値へ変換しておく。
private struct ReceivedContext: Sendable {
    let recentExercisesData: Data?
    let todaySummaryData: Data?

    init(_ raw: [String: Any]) {
        recentExercisesData = raw[WatchSyncKey.recentExercises] as? Data
        todaySummaryData = raw[WatchSyncKey.todaySummary] as? Data
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
        let received = ReceivedContext(session.receivedApplicationContext)
        Task { @MainActor [weak self] in
            self?.applyReceivedContext(received)
            self?.flushPendingLoggedSets()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let received = ReceivedContext(applicationContext)
        Task { @MainActor [weak self] in
            self?.applyReceivedContext(received)
        }
    }
}
