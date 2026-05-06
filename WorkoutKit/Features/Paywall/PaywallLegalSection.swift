// MARK: - PaywallLegalSection
// 利用規約 / プライバシーポリシーへのリンクセクション。
// PaywallSections.swift から分離(CLAUDE.md「1 ファイル 300 行超で分割」)。
//
// =====================================================================
// 🚨 RELEASE BLOCKER 🚨 - App Store Connect 申請前(Phase P-5)に
//   `placeholderTermsURL` / `placeholderPrivacyURL` を本番 URL に
//   差し替えること。確定 URL は Apple Developer 登録後に決まる。
//   差し替え漏れがあると審査で reject される可能性が高い。
// =====================================================================

import SwiftUI

struct PaywallLegalLinks: View {

    // ⚠️ 本番 URL に差し替え必須(Phase P-5)。RELEASE_AUDIT.md / RELEASE
    //   CHECKLIST にも記載済み。CLAUDE.md §-1 に従い App Store 公開時に確定。
    private static let placeholderTermsURL   = URL(string: "https://workoutkit.app/terms")
    private static let placeholderPrivacyURL = URL(string: "https://workoutkit.app/privacy")

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
