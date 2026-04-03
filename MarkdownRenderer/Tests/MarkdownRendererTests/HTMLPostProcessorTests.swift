import Testing
@testable import MarkdownRenderer

@Suite struct HTMLPostProcessorTests {

    // MARK: - Emoji shortcodes

    @Test func emojiShortcodeConverted() {
        let result = HTMLPostProcessor.convertEmojiShortcodes("<p>Hello :smile:</p>")
        #expect(result == "<p>Hello 😄</p>")
    }

    @Test func emojiMultipleShortcodes() {
        let result = HTMLPostProcessor.convertEmojiShortcodes(":thumbsup: and :heart:")
        #expect(result.contains("👍"))
        #expect(result.contains("❤️"))
    }

    @Test func emojiUnknownShortcodeUnchanged() {
        let result = HTMLPostProcessor.convertEmojiShortcodes(":not_a_real_emoji:")
        #expect(result == ":not_a_real_emoji:")
    }

    @Test func emojiInsideCodeBlockUnchanged() {
        let result = HTMLPostProcessor.convertEmojiShortcodes("<pre><code>:smile:</code></pre>")
        #expect(result == "<pre><code>:smile:</code></pre>")
    }

    @Test func emojiInsideInlineCodeUnchanged() {
        let result = HTMLPostProcessor.convertEmojiShortcodes("<p>Use <code>:smile:</code> syntax</p>")
        #expect(result.contains("<code>:smile:</code>"))
    }

    // MARK: - Highlight

    @Test func highlightConverted() {
        let result = HTMLPostProcessor.convertHighlight("<p>This is ==important== text</p>")
        #expect(result.contains("<mark>important</mark>"))
    }

    @Test func highlightMultiple() {
        let result = HTMLPostProcessor.convertHighlight("==one== and ==two==")
        #expect(result.contains("<mark>one</mark>"))
        #expect(result.contains("<mark>two</mark>"))
    }

    @Test func highlightInsideCodeBlockUnchanged() {
        let result = HTMLPostProcessor.convertHighlight("<pre><code>a == b</code></pre>")
        #expect(result == "<pre><code>a == b</code></pre>")
    }

    // MARK: - Superscript

    @Test func superscriptConverted() {
        let result = HTMLPostProcessor.convertSuperscript("<p>x^2^</p>")
        #expect(result.contains("<sup>2</sup>"))
    }

    @Test func superscriptInsideCodeBlockUnchanged() {
        let result = HTMLPostProcessor.convertSuperscript("<pre><code>x^2^</code></pre>")
        #expect(result == "<pre><code>x^2^</code></pre>")
    }

    // MARK: - Subscript

    @Test func subscriptConverted() {
        let result = HTMLPostProcessor.convertSubscript("<p>H~2~O</p>")
        #expect(result.contains("<sub>2</sub>"))
    }

    @Test func subscriptDoesNotAffectStrikethrough() {
        let result = HTMLPostProcessor.convertSubscript("<del>struck</del>")
        #expect(result == "<del>struck</del>")
    }

    @Test func subscriptInsideCodeBlockUnchanged() {
        let result = HTMLPostProcessor.convertSubscript("<pre><code>H~2~O</code></pre>")
        #expect(result == "<pre><code>H~2~O</code></pre>")
    }

    // MARK: - Autolinks

    @Test func autolinkConverted() {
        let result = HTMLPostProcessor.convertAutolinks("<p>Visit https://example.com today</p>")
        #expect(result.contains("<a href=\"https://example.com\">https://example.com</a>"))
    }

    @Test func autolinkDoesNotDoubleWrap() {
        let input = "<a href=\"https://example.com\">https://example.com</a>"
        let result = HTMLPostProcessor.convertAutolinks(input)
        #expect(!result.contains("<a href=\"https://example.com\"><a"))
    }

    @Test func autolinkSkipsExistingHref() {
        let input = "<a href=\"https://example.com\">link</a>"
        let result = HTMLPostProcessor.convertAutolinks(input)
        #expect(result == input)
    }

    @Test func autolinkInsideCodeBlockUnchanged() {
        let input = "<pre><code>https://example.com</code></pre>"
        let result = HTMLPostProcessor.convertAutolinks(input)
        #expect(result == input)
    }

    @Test func autolinkDoesNotDoubleEscapeAmpersand() {
        // URLs in text segments are already HTML-escaped by the visitor
        let input = "<p>Visit https://example.com?a=1&amp;b=2 today</p>"
        let result = HTMLPostProcessor.convertAutolinks(input)
        // Should NOT produce &amp;amp;
        #expect(!result.contains("&amp;amp;"))
        #expect(result.contains("href=\"https://example.com?a=1&amp;b=2\""))
    }

    // MARK: - Smart quotes

    @Test func smartDoubleQuotes() {
        let result = HTMLPostProcessor.convertSmartQuotes("<p>She said \"hello\"</p>")
        #expect(result.contains("\u{201C}hello\u{201D}"))
    }

    @Test func smartApostrophe() {
        let result = HTMLPostProcessor.convertSmartQuotes("<p>it's fine</p>")
        #expect(result.contains("it\u{2019}s"))
    }

    @Test func smartQuotesDoNotCorruptHTMLAttributes() {
        let input = "<a href=\"https://example.com\">link</a>"
        let result = HTMLPostProcessor.convertSmartQuotes(input)
        #expect(result.contains("href=\"https://example.com\""))
    }

    @Test func smartQuotesInsideCodeBlockUnchanged() {
        let input = "<pre><code>\"hello\"</code></pre>"
        let result = HTMLPostProcessor.convertSmartQuotes(input)
        #expect(result == input)
    }

    // MARK: - Footnotes

    @Test func footnotesConverted() {
        let input = "<p>Text with a note[^1]</p>\n<p>[^1]: This is the footnote.</p>\n"
        let result = HTMLPostProcessor.convertFootnotes(input)
        #expect(result.contains("fnref-1"))
        #expect(result.contains("fn-1"))
        #expect(result.contains("This is the footnote."))
        #expect(result.contains("<section class=\"footnotes\">"))
    }

    @Test func footnotesNoDefinitionsUnchanged() {
        let input = "<p>No footnotes here</p>\n"
        let result = HTMLPostProcessor.convertFootnotes(input)
        #expect(result == input)
    }

    @Test func footnotesMultiple() {
        let input = "<p>First[^a] and second[^b]</p>\n<p>[^a]: Note A.</p>\n<p>[^b]: Note B.</p>\n"
        let result = HTMLPostProcessor.convertFootnotes(input)
        #expect(result.contains("fn-a"))
        #expect(result.contains("fn-b"))
        #expect(result.contains("Note A."))
        #expect(result.contains("Note B."))
    }

    @Test func footnoteIdEscaped() {
        let input = "<p>Text[^x\"y]</p>\n<p>[^x\"y]: Note.</p>\n"
        let result = HTMLPostProcessor.convertFootnotes(input)
        #expect(result.contains("fn-x&quot;y"))
        #expect(!result.contains("fn-x\"y"))
    }

    // MARK: - XSS protection

    @Test func frontmatterXSSEscaped() {
        let html = HTMLTemplate.frontmatterHTML([
            (key: "<script>alert(1)</script>", value: "<img src=x onerror=alert(1)>")
        ])
        #expect(html.contains("&lt;script&gt;"))
        #expect(html.contains("&lt;img"))
        // Raw HTML tags must be escaped — no executable tags in output
        #expect(!html.contains("<script>"))
        #expect(!html.contains("<img"))
    }

    @Test func frontmatterXSSEscapesSingleQuotes() {
        let html = HTMLTemplate.frontmatterHTML([
            (key: "test", value: "it's a 'trap'")
        ])
        #expect(html.contains("&#39;"))
        #expect(!html.contains("'trap'"))
    }

    // MARK: - Full pipeline

    @Test func processAppliesAllTransformations() {
        let input = "<p>Hello :rocket: with ==highlight== and x^2^ in H~2~O</p>\n"
        let result = HTMLPostProcessor.process(input)
        #expect(result.contains("🚀"))
        #expect(result.contains("<mark>highlight</mark>"))
        #expect(result.contains("<sup>2</sup>"))
        #expect(result.contains("<sub>2</sub>"))
    }

    @Test func processSkipsCodeBlocks() {
        let input = "<p>:smile:</p>\n<pre><code>:smile: == x^2^ ~sub~ \"quoted\"</code></pre>\n"
        let result = HTMLPostProcessor.process(input)
        // Text outside code should be transformed
        #expect(result.contains("😄"))
        // Code block should be untouched
        #expect(result.contains("<code>:smile: == x^2^ ~sub~ \"quoted\"</code>"))
    }
}
