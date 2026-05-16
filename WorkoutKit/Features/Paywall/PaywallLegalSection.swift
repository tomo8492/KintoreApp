// MARK: - PaywallLegalSection
// 利用規約 / プライバシーポリシーへのリンクセクション。
// PaywallSections.swift から分離(CLAUDE.md「1 ファイル 300 行超で分割」)。
//
// =====================================================================
// 公開先 URL(v1.0 launch、GitHub Pages):
//   - https://tomo8492.github.io/KintoreApp/legal/privacy-policy.html    (ja)
//   - https://tomo8492.github.io/KintoreApp/legal/privacy-policy.en.html (en)
//   - https://tomo8492.github.io/KintoreApp/legal/terms-of-service.html    (ja)
//   - https://tomo8492.github.io/KintoreApp/legal/terms-of-service.en.html (en)
//
// 雛形 .md / 生成 .html は `docs/legal/` 配下にコミット済み。
// GitHub Pages を `docs/` フォルダ source で有効化すれば配信される。
//
// もし将来独自ドメイン (`workoutkit.app` 等) を取得する場合は、本ファイル
// の 2 定数を書き換えるだけで切替可能(`docs/app-store/urls.md` も同期)。
// =====================================================================

import SwiftUI

struct PaywallLegalLinks: View {

    // v1.0 launch URL(GitHub Pages 配信)。ロケール別 URL に切替えたい場合は
    // `Bundle.main.preferredLocalizations.first` を見て .en.html へ分岐する形に
    // リファクタする(現状は ja 既定の単一 URL でも審査は通る前提)。
    private static let placeholderTermsURL   = URL(string: "https://tomo8492.github.io/KintoreApp/legal/terms-of-service.html")
    private static let placeholderPrivacyURL = URL(string: "https://tomo8492.github.io/KintoreApp/legal/privacy-policy.html")

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                if let termsURL = Self.placeholderTermsURL {
                    Link(
                        // ⚠️ RELEASE BLOCKER: 確定後に Self.placeholderTermsURL を
                        //   本番 URL に差し替えるか、Bundle/Info.plist 経由で読む形へ移行。
                        String(localized: "paywall.legal.terms", defaultValue: "利用規約"),
                        destination: termsURL
                    )
                }
                if let privacyURL = Self.placeholderPrivacyURL {
                    Link(
                        // ⚠️ RELEASE BLOCKER: 確定後に Self.placeholderPrivacyURL を
                        //   本番 URL に差し替えること。
                        String(localized: "paywall.legal.privacy", defaultValue: "プライバシーポリシー"),
                        destination: privacyURL
                    )
                }
            }
            .font(.footnote)

            Text(String(
                localized: "paywall.legal.disclaimer",
                defaultValue: "購入は Apple ID に紐づきます。返金・払い戻しは App Store の規定に従います。"
            ))
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
