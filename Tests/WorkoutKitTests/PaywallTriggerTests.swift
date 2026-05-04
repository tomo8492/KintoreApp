// MARK: - PaywallTriggerTests
// CLAUDE.md §-1.14 / §9.1 準拠。
// PaywallTrigger.gate の許可・拒否ロジックと ProFeatureGate.check の振る舞いを凍結する。
// SwiftUI の Binding をテストするためのインメモリラッパを使う。

import Foundation
import SwiftUI
import Testing
@testable import WorkoutKit

@MainActor
@Suite("PaywallTrigger")
struct PaywallTriggerTests {

    // MARK: - Helpers

    /// テストで Binding<T?> を構築するためのインメモリ保持。
    /// SwiftUI の @State を使わず、参照型でラップして外から read/write 可能にする。
    @MainActor
    private final class Box<T> {
        var value: T
        init(_ value: T) { self.value = value }
        var binding: Binding<T> {
            Binding(get: { self.value }, set: { self.value = $0 })
        }
    }

    // MARK: - gate(): isPro 無し

    @Test("isPro=false でロック中の機能にアクセスすると paywall に context が立つ、onAccess は呼ばれない")
    func gateBlocksWhenLocked() {
        let gate = ProFeatureGate()
        let paywall = Box<PaywallContext?>(nil)
        var didAccess = false

        PaywallTrigger.gate(
            .unlimitedHistory,
            proGate: gate,
            paywall: paywall.binding,
            onAccess: { didAccess = true }
        )

        #expect(didAccess == false)
        #expect(paywall.value?.feature == .unlimitedHistory)
    }

    @Test("isPro=true なら onAccess が呼ばれ、paywall は nil のまま")
    func gateAllowsWhenUnlocked() {
        let gate = ProFeatureGate()
        gate._setProForPreview(true)
        let paywall = Box<PaywallContext?>(nil)
        var accessCount = 0

        PaywallTrigger.gate(
            .csvImport,
            proGate: gate,
            paywall: paywall.binding,
            onAccess: { accessCount += 1 }
        )

        #expect(accessCount == 1)
        #expect(paywall.value == nil)
    }

    @Test("各 ProFeature について isPro=false で paywall に正しい feature が乗る")
    func gateRoutesEachFeatureCorrectly() {
        let gate = ProFeatureGate()

        for feature in ProFeature.allCases {
            let paywall = Box<PaywallContext?>(nil)
            var accessed = false
            PaywallTrigger.gate(
                feature,
                proGate: gate,
                paywall: paywall.binding,
                onAccess: { accessed = true }
            )
            // 現状すべて Pro 限定(isFreeTier == false)なので blocked
            #expect(feature.isFreeTier == false)
            #expect(accessed == false)
            #expect(paywall.value?.feature == feature)
        }
    }

    // MARK: - PaywallContext

    @Test("PaywallContext.id は feature.rawValue と一致(Identifiable 用)")
    func paywallContextIdentity() {
        for feature in ProFeature.allCases {
            let ctx = PaywallContext(feature: feature)
            #expect(ctx.id == feature.rawValue)
        }
    }

    @Test("PaywallContext は Hashable: 同じ feature なら同等")
    func paywallContextEquality() {
        let a = PaywallContext(feature: .csvImport)
        let b = PaywallContext(feature: .csvImport)
        let c = PaywallContext(feature: .csvExport)
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - ProFeatureGate.check / setIsPro

    @Test("ProFeatureGate.check は isPro=false で feature.isFreeTier に従う")
    func checkRespectsFreeTier() {
        let gate = ProFeatureGate()
        // 現実の ProFeature はすべて Pro 限定なのでロック中は全部 false
        for feature in ProFeature.allCases {
            #expect(gate.check(feature) == false)
        }

        gate._setProForPreview(true)
        for feature in ProFeature.allCases {
            #expect(gate.check(feature) == true)
        }
    }

    @Test("setIsPro は同値呼び出しで idempotent")
    func setIsProIsIdempotent() {
        let gate = ProFeatureGate()
        #expect(gate.isPro == false)

        gate.setIsPro(false)
        #expect(gate.isPro == false)

        gate.setIsPro(true)
        #expect(gate.isPro == true)
        gate.setIsPro(true)
        #expect(gate.isPro == true)
    }

    @Test("nonisolated init で MainActor 隔離なしに ProFeatureGate を構築できる")
    nonisolated func nonisolatedInitWorks() {
        // EnvironmentKey.defaultValue 等から呼べる必要がある(NG リスト規約)。
        // ここでは構築できるかだけ確認。状態にアクセスしないので nonisolated でも安全。
        let gate = ProFeatureGate()
        _ = gate
    }
}
