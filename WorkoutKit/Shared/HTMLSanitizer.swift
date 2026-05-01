// MARK: - HTMLSanitizer
// CLAUDE.md §11.4(NGリスト) / §-1.6 準拠。
// workout-cool 由来の Exercise.descriptionJa/En を AttributedString に渡す前に、
// XSS/レンダラ汚染の原因になりうるタグ・属性を機械的に除去する。
//
// 設計方針:
//   - 完全な HTML パーサは作らない。NSAttributedString(data:options:[.html]) に渡す前段の
//     "前処理" として動作する正規表現ベースのフィルタ。
//   - 残すホワイトリスト: <p>, <ol>, <ul>, <li>, <strong>, <em>, <br>, <a>
//   - 攻撃面の落とし方:
//       1. 危険な要素 (script/iframe/object/embed/link/style/meta/base/applet/frame/frameset)
//          を「タグ + 内容」ごと除去
//       2. インラインイベントハンドラ属性 (onclick / onload / on*) を全削除
//       3. href / src の javascript: および data: URI を該当属性ごと削除
//   - 入力が壊れていても throw しない / クラッシュしない。これはテストで担保する。

import Foundation

enum HTMLSanitizer {

    // MARK: - Public

    /// 入力 HTML を AttributedString レンダリング向けに無害化して返す。
    /// 失敗しない(壊れた HTML でも何らかの String を返す)。
    static func sanitize(_ html: String) -> String {
        var s = html

        // 1) 中身を持つ危険要素: <script>...</script> 等を内容ごと丸ごと削除
        for tag in elementsToStripWithContent {
            s = stripPairedTag(tag, in: s)
        }

        // 2) Void / 自閉じ要素: <link ...>, <embed ...>, <meta ...>, <base ...>
        for tag in voidElementsToStrip {
            s = stripVoidTag(tag, in: s)
        }

        // 3) インラインイベントハンドラ属性 (onclick="..." / onload='...' / onerror=...)
        s = stripInlineEventHandlers(in: s)

        // 4) href / src に潜む javascript: / data: スキーム → 属性ごと削除
        s = stripDangerousURISchemes(in: s)

        return s
    }

    // MARK: - Constants

    /// 開始タグ + 中身 + 終了タグごと削除する要素。
    private static let elementsToStripWithContent: [String] = [
        "script", "style", "iframe", "object", "applet", "frameset", "frame", "noscript"
    ]

    /// 自閉じ・void 要素として削除する要素。
    private static let voidElementsToStrip: [String] = [
        "link", "embed", "meta", "base"
    ]

    // MARK: - Building blocks

    /// `<tag ...>...</tag>` を中身ごと削除する。
    /// 開始タグだけ / 終了タグだけが残った不正 HTML も同時に掃除する。
    private static func stripPairedTag(_ tag: String, in input: String) -> String {
        var s = input
        // 中身ごと(非貪欲)
        let paired = "<\\s*\(tag)\\b[^>]*>[\\s\\S]*?<\\s*/\\s*\(tag)\\s*>"
        s = s.replacingOccurrences(
            of: paired,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        // 開始タグだけ残った場合
        let openOnly = "<\\s*\(tag)\\b[^>]*>"
        s = s.replacingOccurrences(
            of: openOnly,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        // 終了タグだけ残った場合
        let closeOnly = "<\\s*/\\s*\(tag)\\s*>"
        s = s.replacingOccurrences(
            of: closeOnly,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        return s
    }

    /// `<tag ... />` / `<tag ...>` を削除する(中身を持たない要素)。
    private static func stripVoidTag(_ tag: String, in input: String) -> String {
        let pattern = "<\\s*\(tag)\\b[^>]*/?>"
        return input.replacingOccurrences(
            of: pattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    /// インラインイベントハンドラ属性 (`on*=...`) を、属性ごと削除する。
    /// HTML5 仕様上、`on` で始まる属性はすべてイベントハンドラ。
    private static func stripInlineEventHandlers(in input: String) -> String {
        // 直前の空白も含めて除去する。値はクオート有り("..." / '...') / クオート無しの3パターン。
        let pattern = "\\s+on[a-zA-Z]+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)"
        return input.replacingOccurrences(
            of: pattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    /// `href` / `src` に javascript: または data: スキームが現れた場合、
    /// その属性自体をまとめて削除する(値だけ消すと壊れた HTML が残るため)。
    private static func stripDangerousURISchemes(in input: String) -> String {
        var s = input
        // ダブルクオート / シングルクオート / クオート無し の3パターンを別々に処理する。
        // 後方参照に頼らないことで NSRegularExpression の差異を踏まない。
        let patterns: [String] = [
            // href="javascript:..." / src="data:..."
            "\\s+(href|src)\\s*=\\s*\"\\s*(?:javascript|data)\\s*:[^\"]*\"",
            // href='javascript:...'
            "\\s+(href|src)\\s*=\\s*'\\s*(?:javascript|data)\\s*:[^']*'",
            // href=javascript:... (クオート無し)
            "\\s+(href|src)\\s*=\\s*(?:javascript|data)\\s*:[^\\s>]*"
        ]
        for pattern in patterns {
            s = s.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return s
    }
}
