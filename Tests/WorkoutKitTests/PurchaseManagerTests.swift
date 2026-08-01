// MARK: - PurchaseManagerTests
// CLAUDE.md v1.0 §3-3 / §6-4 準拠。
//
// PurchaseManager 本体(configureIfPossible / refresh / fetchOffering / purchase /
// restore / apply)は `Purchases.shared` という RevenueCat のグローバル singleton に
// 依存しており、ユニットテストから安全に構成(API key configure)できない
// (ネットワーク呼び出し・実 StoreKit 環境が必要)。また `plan(from:)` /
// `daysIn(_:)` / `eligibilityAdjustedPlan(from:)` は private のため @testable import
// でも呼び出せない(private はファイルスコープ限定で、テストファイルからは不可視)。
//
// そのため本ファイルでは、RevenueCat 型にもネットワークにも依存しない
// 「素の値」だけで構築できる公開データ型(PurchaseError の errorDescription
// マッピング、PurchaseOffering / PurchasePlan / PurchaseResultOutcome の
// Equatable 挙動、C3 で追加した PurchaseOffering.yearlySavings の Decimal 計算)
// のみを対象にする。
//
// C2/C3 で `PurchasePlan` に `price: Decimal` / `currencyCode: String?` が追加された
// ため、既存ケースはすべて明示的にこの2つを渡すよう更新している。

import Foundation
import Testing
@testable import WorkoutKit

@Suite("PurchaseManager (pure data types)")
struct PurchaseManagerTests {

    // MARK: - PurchaseError.errorDescription

    @Test("PurchaseError の固定ケースは空でない errorDescription を持つ")
    func fixedCasesHaveNonEmptyDescription() {
        let cases: [PurchaseError] = [.notConfigured, .noOfferings, .productNotAvailable, .userCancelled]
        for error in cases {
            #expect(error.errorDescription?.isEmpty == false, "\(error) has empty description")
        }
    }

    @Test("PurchaseError の固定ケースはそれぞれ異なる errorDescription を持つ(キー衝突なし)")
    func fixedCasesHaveDistinctDescriptions() {
        let cases: [PurchaseError] = [.notConfigured, .noOfferings, .productNotAvailable, .userCancelled]
        let descriptions = Set(cases.compactMap(\.errorDescription))
        #expect(descriptions.count == cases.count)
    }

    @Test("PurchaseError.underlying は渡したメッセージをそのまま errorDescription として返す")
    func underlyingCasePassesThroughMessage() {
        let error = PurchaseError.underlying("network timeout")
        #expect(error.errorDescription == "network timeout")
    }

    // MARK: - PurchaseOffering / PurchasePlan Equatable

    @Test("PurchasePlan は Equatable: 全フィールド一致で等しい")
    func purchasePlanEquality() {
        let a = PurchasePlan(productID: "workoutkit_yearly_4900", displayPrice: "¥4,900", trialDays: 7, price: 4900, currencyCode: "JPY", rcIdentifier: "yearly")
        let b = PurchasePlan(productID: "workoutkit_yearly_4900", displayPrice: "¥4,900", trialDays: 7, price: 4900, currencyCode: "JPY", rcIdentifier: "yearly")
        let c = PurchasePlan(productID: "workoutkit_monthly_680", displayPrice: "¥680", trialDays: 7, price: 680, currencyCode: "JPY", rcIdentifier: "monthly")
        #expect(a == b)
        #expect(a != c)
    }

    @Test("PurchaseOffering は Equatable: monthly/yearly の組み合わせで比較できる")
    func purchaseOfferingEquality() {
        let yearly = PurchasePlan(productID: "workoutkit_yearly_4900", displayPrice: "¥4,900", trialDays: 7, price: 4900, currencyCode: "JPY", rcIdentifier: "yearly")
        let monthly = PurchasePlan(productID: "workoutkit_monthly_680", displayPrice: "¥680", trialDays: 7, price: 680, currencyCode: "JPY", rcIdentifier: "monthly")

        let a = PurchaseOffering(monthly: monthly, yearly: yearly)
        let b = PurchaseOffering(monthly: monthly, yearly: yearly)
        let onlyYearly = PurchaseOffering(monthly: nil, yearly: yearly)

        #expect(a == b)
        #expect(a != onlyYearly)
    }

    @Test("PurchasePlan.trialDays は nil を保持できる(トライアルなしプラン)")
    func purchasePlanWithoutTrial() {
        let plan = PurchasePlan(productID: "workoutkit_monthly_680", displayPrice: "¥680", trialDays: nil, price: 680, currencyCode: "JPY", rcIdentifier: "monthly")
        #expect(plan.trialDays == nil)
    }

    // MARK: - PurchaseResultOutcome

    @Test("PurchaseResultOutcome は Equatable でケースごとに区別できる")
    func purchaseResultOutcomeEquality() {
        #expect(PurchaseResultOutcome.success == .success)
        #expect(PurchaseResultOutcome.success != .cancelled)
        #expect(PurchaseResultOutcome.pending != .cancelled)
    }

    // MARK: - PurchaseOffering.yearlySavings (C3)

    @Test("yearlySavings: 月額 ¥680 × 12 と年額 ¥4,900 から お得額/割引率/月あたり換算 を Decimal で算出する")
    func yearlySavingsComputesFromRealPrices() {
        let monthly = PurchasePlan(productID: "workoutkit_monthly_680", displayPrice: "¥680", trialDays: 7, price: 680, currencyCode: "JPY", rcIdentifier: "monthly")
        let yearly = PurchasePlan(productID: "workoutkit_yearly_4900", displayPrice: "¥4,900", trialDays: 7, price: 4_900, currencyCode: "JPY", rcIdentifier: "yearly")
        let offering = PurchaseOffering(monthly: monthly, yearly: yearly)

        let savings = offering.yearlySavings
        #expect(savings != nil)
        // 680 * 12 = 8,160 / 8,160 - 4,900 = 3,260 / 3,260 / 8,160 * 100 ≈ 39.95% → 四捨五入で 40。
        #expect(savings?.percentOff == 40)
        // 桁区切り記号や通貨記号はロケール依存なので、数字だけ抜き出して比較する(CI ロケール非依存)。
        #expect(savings?.savingsText.filter(\.isNumber) == "3260")
        // 4,900 / 12 ≈ 408.33 → 表示は小数点以下切り捨て/丸めのどちらでも "408"。
        #expect(savings?.monthlyEquivalentText.filter(\.isNumber) == "408")
    }

    @Test("yearlySavings: monthly が nil なら算出できない")
    func yearlySavingsNilWhenMonthlyMissing() {
        let yearly = PurchasePlan(productID: "workoutkit_yearly_4900", displayPrice: "¥4,900", trialDays: 7, price: 4_900, currencyCode: "JPY", rcIdentifier: "yearly")
        let offering = PurchaseOffering(monthly: nil, yearly: yearly)
        #expect(offering.yearlySavings == nil)
    }

    @Test("yearlySavings: 年額が月額 ×12 以上(お得なし)なら算出できない")
    func yearlySavingsNilWhenNoActualSavings() {
        let monthly = PurchasePlan(productID: "workoutkit_monthly_680", displayPrice: "¥680", trialDays: 7, price: 680, currencyCode: "JPY", rcIdentifier: "monthly")
        let yearly = PurchasePlan(productID: "workoutkit_yearly_9999", displayPrice: "¥9,999", trialDays: 7, price: 9_999, currencyCode: "JPY", rcIdentifier: "yearly")
        let offering = PurchaseOffering(monthly: monthly, yearly: yearly)
        #expect(offering.yearlySavings == nil)
    }
}
