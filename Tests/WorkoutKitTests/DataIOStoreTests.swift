// MARK: - DataIOStoreTests
// CLAUDE.md §1.1 F-06 / §-1.14 / §11.4 / §9.1 準拠。
// post-purchase verification 監査で見つけた defect の回帰防止:
//   旧 showProPaywall(for:) は AppError を alert で表示するだけで
//   購入導線が無く、Pro 機能を解放する経路が断たれていた。
// 修正後は paywallFeature を立てて DataIOView 側で PaywallView を
// 提示する。本テストは「alert ではなく paywallFeature が立つ」ことを凍結する。

import Testing
@testable import WorkoutKit

@Suite("DataIOStore")
@MainActor
struct DataIOStoreTests {

    @Test("showProPaywall は alert ではなく paywallFeature を立てる")
    func showProPaywallSetsPaywallFeature() {
        let store = DataIOStore()
        #expect(store.paywallFeature == nil)
        #expect(store.isAlertPresented == false)
        #expect(store.alertMessage == nil)

        store.showProPaywall(for: .csvImport)

        #expect(store.paywallFeature == .csvImport)
        // alert 系は触らない(Import / Export 失敗時の本来の用途のみ)。
        #expect(store.isAlertPresented == false)
        #expect(store.alertMessage == nil)
    }

    @Test("showProPaywall は別 feature でも上書きできる")
    func showProPaywallOverwrites() {
        let store = DataIOStore()
        store.showProPaywall(for: .csvImport)
        #expect(store.paywallFeature == .csvImport)
        store.showProPaywall(for: .csvExport)
        #expect(store.paywallFeature == .csvExport)
    }

    @Test("presentError は import/export 失敗時の alert path で paywallFeature は触らない")
    func presentErrorIsSeparate() {
        let store = DataIOStore()
        store.presentError(AppError.importFailed(reason: "boom"))
        #expect(store.isAlertPresented == true)
        #expect(store.alertMessage != nil)
        #expect(store.paywallFeature == nil)
    }
}
