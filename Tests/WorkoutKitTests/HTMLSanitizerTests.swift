// MARK: - HTMLSanitizerTests
// CLAUDE.md §9.1 / §11.4 準拠。Swift Testing でサニタイザの最低保証を凍結する。
// XSS の主要ベクタ(script / iframe / inline event / javascript: URI)が除去されること、
// 表示用の安全タグが残ること、不正 HTML でクラッシュしないことを確認する。

import Testing
@testable import WorkoutKit

@Suite("HTMLSanitizer")
struct HTMLSanitizerTests {

    // MARK: - Strip dangerous elements

    @Test("script タグ + 中身が丸ごと除去される")
    func stripsScriptTag() {
        let input = "<p>Hello</p><script>alert('xss')</script>"
        let output = HTMLSanitizer.sanitize(input)
        #expect(!output.lowercased().contains("script"))
        #expect(!output.contains("alert"))
        #expect(output.contains("<p>"))
        #expect(output.contains("Hello"))
    }

    @Test("属性付きの script タグも除去される")
    func stripsScriptWithAttributes() {
        let input = "<script type=\"text/javascript\" src=\"evil.js\">bad()</script><strong>hi</strong>"
        let output = HTMLSanitizer.sanitize(input)
        #expect(!output.lowercased().contains("<script"))
        #expect(!output.contains("bad()"))
        #expect(output.contains("<strong>"))
        #expect(output.contains("hi"))
    }

    @Test("大文字の SCRIPT タグも(case insensitive で)除去される")
    func caseInsensitiveScript() {
        let input = "<P>x</P><SCRIPT>bad</SCRIPT>"
        let output = HTMLSanitizer.sanitize(input)
        #expect(!output.lowercased().contains("script"))
        #expect(!output.contains("bad"))
    }

    @Test("iframe / object / embed / link / style / meta が除去される")
    func stripsOtherDangerousElements() {
        let input = """
        <iframe src="bad.html"></iframe>
        <object data="x"></object>
        <embed src="x" />
        <link rel="stylesheet" href="x.css" />
        <style>body{display:none}</style>
        <meta http-equiv="refresh" content="0;url=x">
        <p>kept</p>
        """
        let output = HTMLSanitizer.sanitize(input)
        let lower = output.lowercased()
        #expect(!lower.contains("<iframe"))
        #expect(!lower.contains("<object"))
        #expect(!lower.contains("<embed"))
        #expect(!lower.contains("<link"))
        #expect(!lower.contains("<style"))
        #expect(!lower.contains("<meta"))
        #expect(output.contains("<p>kept</p>"))
    }

    // MARK: - Strip dangerous attributes

    @Test("インラインイベントハンドラ (onclick) が属性ごと除去される")
    func stripsOnClickHandler() {
        let input = "<a href=\"https://example.com\" onclick=\"steal()\">link</a>"
        let output = HTMLSanitizer.sanitize(input)
        #expect(!output.lowercased().contains("onclick"))
        #expect(!output.contains("steal()"))
        // href は安全なので残ること
        #expect(output.contains("https://example.com"))
        #expect(output.contains("link"))
    }

    @Test("複数のイベントハンドラ (onload / onerror) も除去される")
    func stripsMultipleEventHandlers() {
        let input = "<img src=\"x.png\" onload='boom()' onerror=\"boom2()\" />"
        let output = HTMLSanitizer.sanitize(input)
        let lower = output.lowercased()
        #expect(!lower.contains("onload"))
        #expect(!lower.contains("onerror"))
        #expect(!output.contains("boom()"))
        #expect(!output.contains("boom2()"))
    }

    @Test("href の javascript: URI は属性ごと削除される")
    func stripsJavaScriptHref() {
        let input = "<a href=\"javascript:alert(1)\">click</a>"
        let output = HTMLSanitizer.sanitize(input)
        #expect(!output.lowercased().contains("javascript:"))
        #expect(!output.contains("alert(1)"))
        // タグそのものは残る(href だけ取り除かれる)
        #expect(output.contains("<a"))
        #expect(output.contains("click"))
    }

    @Test("クオート無し / シングルクオートの javascript: URI も削除される")
    func stripsUnquotedAndSingleQuotedJavaScriptHref() {
        let unquoted = "<a href=javascript:alert(1)>x</a>"
        let single = "<a href='javascript:alert(2)'>y</a>"
        #expect(!HTMLSanitizer.sanitize(unquoted).lowercased().contains("javascript:"))
        #expect(!HTMLSanitizer.sanitize(single).lowercased().contains("javascript:"))
    }

    @Test("data: URI も href / src から削除される")
    func stripsDataURI() {
        let input = "<a href=\"data:text/html,<script>x</script>\">x</a>"
        let output = HTMLSanitizer.sanitize(input)
        #expect(!output.lowercased().contains("data:"))
    }

    // MARK: - Preserve safe tags

    @Test("<p>, <strong>, <em> はそのまま残る")
    func preservesBasicInlineFormatting() {
        let input = "<p>This is <strong>bold</strong> and <em>italic</em>.</p>"
        let output = HTMLSanitizer.sanitize(input)
        #expect(output.contains("<p>"))
        #expect(output.contains("</p>"))
        #expect(output.contains("<strong>"))
        #expect(output.contains("</strong>"))
        #expect(output.contains("<em>"))
        #expect(output.contains("</em>"))
        #expect(output.contains("bold"))
        #expect(output.contains("italic"))
    }

    @Test("<ol>, <ul>, <li>, <br> はそのまま残る")
    func preservesListAndBreak() {
        let input = "<ol><li>one</li></ol><ul><li>a</li></ul>line1<br>line2"
        let output = HTMLSanitizer.sanitize(input)
        #expect(output.contains("<ol>"))
        #expect(output.contains("<ul>"))
        #expect(output.contains("<li>"))
        #expect(output.contains("<br>"))
        #expect(output.contains("one"))
        #expect(output.contains("a"))
        #expect(output.contains("line1"))
        #expect(output.contains("line2"))
    }

    @Test("安全な http(s) リンクは href ごと残る")
    func preservesSafeAnchor() {
        let input = "<a href=\"https://example.com/page\">label</a>"
        let output = HTMLSanitizer.sanitize(input)
        #expect(output.contains("<a"))
        #expect(output.contains("href=\"https://example.com/page\""))
        #expect(output.contains("label"))
    }

    // MARK: - Robustness

    @Test("不正 / 壊れた HTML でも例外を投げず文字列を返す")
    func malformedHTMLDoesNotCrash() {
        let inputs: [String] = [
            "",
            "<p>unclosed",
            "<<script>>alert</script>>",
            "<script>partial",
            "</script>",
            "<a href=javascript:alert(1)>noquotes</a>",
            "<P>UPPER</P><SCRIPT>x</SCRIPT>",
            "<p>&amp;&lt;&gt;</p>",
            String(repeating: "<", count: 1000),
            String(repeating: "<script>x</script>", count: 50)
        ]
        for input in inputs {
            // 何度回しても idempotent に近い挙動であること(再 sanitize でも崩壊しない)
            let once = HTMLSanitizer.sanitize(input)
            let twice = HTMLSanitizer.sanitize(once)
            #expect(once.utf8.count >= 0)
            #expect(twice.utf8.count >= 0)
            #expect(!once.lowercased().contains("<script"))
            #expect(!twice.lowercased().contains("<script"))
        }
    }

    @Test("script タグのネスト混入も最終的に除去される")
    func nestedScriptIsRemoved() {
        let input = "<p>ok</p><script><script>alert(1)</script></script>"
        let output = HTMLSanitizer.sanitize(input)
        #expect(!output.lowercased().contains("<script"))
        #expect(!output.lowercased().contains("</script"))
        #expect(!output.contains("alert(1)"))
        #expect(output.contains("<p>ok</p>"))
    }
}
