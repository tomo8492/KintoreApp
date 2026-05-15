// MARK: - AppSecrets
// CLAUDE.md v0.5 §-1.1 / §11.4 NG リスト準拠。
//
// 秘匿情報(RevenueCat API Key 等)を Info.plist 経由で安全に取り出す入口。
// Build Settings 側で `INFOPLIST_KEY_RevenueCatAPIKey = $(REVENUECAT_API_KEY)`
// を渡すと、ビルド時に Info.plist にキーが埋め込まれ、本構造体が参照する。
//
// ソースに API キーを直書きしないための唯一の入口。
// 値が空文字 / 未設定の場合は nil を返し、呼び出し側でフォールバックする。

import Foundation

enum AppSecrets {
    /// Info.plist から取り出した文字列値が空でなければ返す。
    private static func string(forKey key: String) -> String? {
        let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              // Secrets.template.xcconfig のプレースホルダがそのまま残っている場合
              !value.contains("REVENUECAT_PUBLIC_API_KEY_HERE")
        else { return nil }
        return value
    }

    /// RevenueCat 公開 API キー(`appl_xxx` 形式)。
    /// `Config/Secrets.xcconfig` から `REVENUECAT_API_KEY = ...` を渡す。
    static var revenueCatAPIKey: String? {
        string(forKey: "RevenueCatAPIKey")
    }
}
