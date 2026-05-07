// MARK: - PaywallLegalSection
// 利用規約 / プライバシーポリシーへのリンクセクション。
// PaywallSections.swift から分離(CLAUDE.md「1 ファイル 300 行超で分割」)。
//
// =====================================================================
// 🚨 RELEASE BLOCKER 🚨 - App Store Connect 申請前(Phase P-5)に
//   `placeholderTermsURL` / `placeholderPrivacyURL` を本番 URL に
//   差し替えること。確定 URL は Apple Developer 登録後に決まる。
//   差し替え漏れがあると審査で reject される可能性が高い。
//
// 雛形ドキュメントは `docs/legal/` 配下にコミット済み:
//   - docs/legal/privacy-policy.html       (ja)
//   - docs/legal/privacy-policy.en.html    (en)
//   - docs/legal/terms-of-service.html     (ja)
//   - docs/legal/terms-of-service.en.html  (en)
//
// 公開候補 URL(GitHub Pages を有効化した場合):
//   - https://tomo8492.github.io/KintoreApp/legal/privacy-policy.html
//   - https://tomo8492.github.io/KintoreApp/legal/terms-of-service.html
// 独自ドメインを取得する場合は workoutkit.app などへ差し替え。
//
// 公開後、以下を実施:
//   1. `placeholderTermsURL` / `placeholderPrivacyURL` を本番 URL に書き換え
//   2. `docs/legal/*.md` の "2026-XX-XX" を実際の公開日に更新
//   3. `[YOUR_EMAIL]` プレースホルダを連絡先メールアドレスに差し替え
//   4. 必要に応じて Bundle/Info.plist 経由で URL を読み込む形へリファクタ
// =====================================================================

import SwiftUI

struct PaywallLegalLinks: View {

    // ⚠️ 本番 URL に差し替え必須(Phase P-5)。RELEASE_AUDIT.md / RELEASE
    //   CHECKLIST にも記載済み。CLAUDE.md §-1 に従い App Store 公開時に確定。
    //
    // 候補 URL(GitHub Pages 有効化時):
    //   https://tomo8492.github.io/KintoreApp/legal/terms-of-service.html
    //   https://tomo8492.github.io/KintoreApp/legal/privacy-policy.html
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
