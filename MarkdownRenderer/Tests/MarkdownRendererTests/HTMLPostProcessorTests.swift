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

    @Test func emojiInsideHTMLAttributeUnchanged() {
        let result = HTMLPostProcessor.convertEmojiShortcodes("<img alt=\":smile:\">")
        #expect(result == "<img alt=\":smile:\">")
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

    // MARK: - Superscript

    @Test func superscriptConverted() {
        let result = HTMLPostProcessor.convertSuperscript("<p>x^2^</p>")
        #expect(result.contains("<sup>2</sup>"))
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

    // MARK: - Autolinks

    @Test func autolinkConverted() {
        let result = HTMLPostProcessor.convertAutolinks("<p>Visit https://example.com today</p>")
        #expect(result.contains("<a href=\"https://example.com\">https://example.com</a>"))
    }

    @Test func autolinkDoesNotDoubleWrap() {
        let input = "<a href=\"https://example.com\">https://example.com</a>"
        let result = HTMLPostProcessor.convertAutolinks(input)
        // Should not create nested anchors
        #expect(!result.contains("<a href=\"https://example.com\"><a"))
    }

    @Test func autolinkSkipsExistingHref() {
        let input = "<a href=\"https://example.com\">link</a>"
        let result = HTMLPostProcessor.convertAutolinks(input)
        #expect(result == input)
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

    // MARK: - Full pipeline

    @Test func processAppliesAllTransformations() {
        let input = "<p>Hello :rocket: with ==highlight== and x^2^ in H~2~O</p>\n"
        let result = HTMLPostProcessor.process(input)
        #expect(result.contains("🚀"))
        #expect(result.contains("<mark>highlight</mark>"))
        #expect(result.contains("<sup>2</sup>"))
        #expect(result.contains("<sub>2</sub>"))
    }
}
