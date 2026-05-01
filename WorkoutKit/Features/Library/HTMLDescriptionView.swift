// MARK: - HTMLDescriptionView
// CLAUDE.md §1.1 F-02 / §4.1 / §11.4 準拠。
// Exercise.descriptionJa / descriptionEn の HTML を AttributedString として安全に描画する SwiftUI View。
//
// セキュリティ:
//   - レンダリング前に必ず HTMLSanitizer.sanitize(_:) を通す。
//   - サニタイズ後の文字列を NSAttributedString(data:options:[.documentType: .html]) に渡し、
//     AttributedString に変換して Text に流し込む。
//   - 失敗(エンコード失敗 / パース失敗)時は Logger に出して、
//     プレーンテキストにフォールバックする(クラッシュさせない)。
//
// 設計上の注意:
//   - NSAttributedString の HTML パーサは UIKit 提供のため import UIKit が必要。
//   - HTML パーサはメインスレッド前提なので View の MainActor 文脈で呼ぶ。
//     `.task(id:)` 経由なので body の最初の評価をブロックしない。
//   - View には @State を直接持たせる(ViewModel 禁止 / CLAUDE.md §11)。

import SwiftUI
import UIKit
import OSLog

struct HTMLDescriptionView: View {

    /// 描画対象の HTML 文字列(workout-cool 由来の Exercise.descriptionJa / En を想定)。
    let html: String

    @State private var rendered: AttributedString = AttributedString()

    var body: some View {
        Text(rendered)
            .textSelection(.enabled)
            .task(id: html) {
                rendered = Self.render(html: html)
            }
    }

    // MARK: - Rendering

    /// HTML をサニタイズして AttributedString に変換する。
    /// 失敗時は Logger に書いてプレーン文字列でフォールバックする。
    @MainActor
    private static func render(html: String) -> AttributedString {
        let sanitized = HTMLSanitizer.sanitize(html)

        guard let data = sanitized.data(using: .utf8) else {
            Logger.app.error("HTMLDescriptionView: utf8 encode failed")
            return AttributedString(sanitized)
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        do {
            let ns = try NSAttributedString(
                data: data,
                options: options,
                documentAttributes: nil
            )
            return AttributedString(ns)
        } catch {
            Logger.app.error(
                "HTMLDescriptionView: parse failed: \(error.localizedDescription, privacy: .public)"
            )
            return AttributedString(sanitized)
        }
    }
}

#Preview("plain") {
    HTMLDescriptionView(html: "<p>Hello <strong>world</strong>, this is <em>italic</em>.</p>")
        .padding()
}

#Preview("list") {
    HTMLDescriptionView(html: """
        <p>How to:</p>
        <ol>
            <li>Stand with feet shoulder-width apart.</li>
            <li>Lower until thighs are parallel to floor.</li>
            <li>Drive through heels to stand back up.</li>
        </ol>
        """)
        .padding()
}

#Preview("malicious input is sanitized") {
    HTMLDescriptionView(html: """
        <p>Safe text.</p>
        <script>alert('xss')</script>
        <a href="javascript:alert(1)" onclick="bad()">click</a>
        """)
        .padding()
}
