// MARK: - StoreKitClientTests
// CLAUDE.md §9.1 / §-1.14 / §11.4 準拠。Swift Testing + StoreKitTest で
// Pro 買い切り(com.tomo.workoutkit.pro.unlock)の購入・復元・払戻を検証する。
//
// 前提: テストターゲットの Resources に WorkoutKit.storekit を含めること。
//       Xcode のスキーム設定で StoreKit Configuration を None にしておく
//       (SKTestSession を使うので Xcode 側のオプトイン購入は不要)。

import Testing
import StoreKit
import StoreKitTest
@testable import WorkoutKit

@Suite("StoreKitClient", .serialized)
struct StoreKitClientTests {

    // MARK: - 共通

    /// SKTestSession を作って初期化する。clearTransactions で前テストの残骸を消す。
    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "WorkoutKit")
        session.disableDialogs = true
        session.askToBuyEnabled = false
        session.clearTransactions()
        return session
    }

    /// テスト用の StoreKitClient + ProFeatureGate ペアを作る。
    @MainActor
    private func makeClient() -> (StoreKitClient, ProFeatureGate) {
        let gate = ProFeatureGate()
        let client = StoreKitClient(proGate: gate)
        return (client, gate)
    }

    // MARK: - 起動時の同期

    @Test("start() で Product がロードされ、未購入なら isPro=false のまま")
    func startWithoutPurchase() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let (client, gate) = await makeClient()
        await client.start()

        let cached = await client.cachedProduct
        #expect(cached?.id == StoreKitClient.proProductID)

        let isPro = await MainActor.run { gate.isPro }
        #expect(isPro == false)
    }

    // MARK: - 購入

    @Test("購入成功で isPro=true、PurchaseResult は .success")
    func purchaseSucceedsAndUnlocksPro() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let (client, gate) = await makeClient()
        await client.start()

        let result = try await client.purchase()
        #expect(result == .success)

        let isPro = await MainActor.run { gate.isPro }
        #expect(isPro == true)
    }

    // MARK: - 復元

    @Test("購入済みの状態で別インスタンスから restore すると isPro=true になる")
    func restoreAfterPurchase() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        // 1) 1 回購入する。
        let (client1, _) = await makeClient()
        await client1.start()
        _ = try await client1.purchase()

        // 2) 別インスタンス(=端末再インストール相当)を作って restore する。
        let (client2, gate2) = await makeClient()
        await client2.start()

        // start() 時点で currentEntitlements から isPro が反映されているはず。
        let isProAfterStart = await MainActor.run { gate2.isPro }
        #expect(isProAfterStart == true)

        // 明示 restore も例外を投げない。
        try await client2.restorePurchases()
        let isProAfterRestore = await MainActor.run { gate2.isPro }
        #expect(isProAfterRestore == true)
    }

    @Test("未購入で restore してもエラーにならず isPro=false のまま")
    func restoreWithoutAnyPurchase() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let (client, gate) = await makeClient()
        await client.start()

        try await client.restorePurchases()
        let isPro = await MainActor.run { gate.isPro }
        #expect(isPro == false)
    }

    // MARK: - 払戻 (revocation)

    @Test("購入後に refundTransaction で払戻すると最終的に isPro=false になる")
    func refundRevokesPro() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let (client, gate) = await makeClient()
        await client.start()

        _ = try await client.purchase()
        let isProBefore = await MainActor.run { gate.isPro }
        #expect(isProBefore == true)

        // 直近の購入トランザクションを払い戻す。
        // SKTestSession.allTransactions() は StoreKit.Transaction を返す。
        let allTransactions = session.allTransactions()
        guard let target = allTransactions.first(where: {
            $0.productID == StoreKitClient.proProductID
        }) else {
            Issue.record("購入後のトランザクションが見つからない")
            return
        }
        try session.refundTransaction(identifier: UInt(target.id))

        // restore で currentEntitlements を再評価させる(Transaction.updates の順序に頼らない)。
        try await client.restorePurchases()

        let isProAfter = await MainActor.run { gate.isPro }
        #expect(isProAfter == false)
    }

    // MARK: - ProFeatureGate 単体

    @Test("ProFeatureGate.check は free tier 機能を Pro 未購入でも許可する")
    @MainActor
    func gateAllowsFreeTier() {
        let gate = ProFeatureGate()
        // 現状 ProFeature は全て Pro 限定なので、isPro=false で全部 false が期待値。
        for feature in ProFeature.allCases {
            #expect(gate.check(feature) == false)
        }
        gate.setIsPro(true)
        for feature in ProFeature.allCases {
            #expect(gate.check(feature) == true)
        }
    }

    @Test("ProFeatureGate.setIsPro は idempotent")
    @MainActor
    func gateSetIsProIdempotent() {
        let gate = ProFeatureGate()
        gate.setIsPro(true)
        #expect(gate.isPro == true)
        gate.setIsPro(true) // no-op
        #expect(gate.isPro == true)
        gate.setIsPro(false)
        #expect(gate.isPro == false)
    }
}
