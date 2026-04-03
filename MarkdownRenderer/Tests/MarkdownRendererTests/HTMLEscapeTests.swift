import Testing
@testable import MarkdownRenderer

@Suite struct HTMLEscapeTests {
    @Test func escapesAmpersand() {
        #expect(HTMLEscape.escape("a & b") == "a &amp; b")
    }

    @Test func escapesLessThan() {
        #expect(HTMLEscape.escape("a < b") == "a &lt; b")
    }

    @Test func escapesGreaterThan() {
        #expect(HTMLEscape.escape("a > b") == "a &gt; b")
    }

    @Test func escapesDoubleQuote() {
        #expect(HTMLEscape.escape("say \"hi\"") == "say &quot;hi&quot;")
    }

    @Test func escapesSingleQuote() {
        #expect(HTMLEscape.escape("it's") == "it&#39;s")
    }

    @Test func escapesAllSpecialChars() {
        let input = "<script>alert('xss' & \"more\")</script>"
        let result = HTMLEscape.escape(input)
        #expect(!result.contains("<"))
        #expect(!result.contains(">"))
        #expect(!result.contains("\""))
        #expect(!result.contains("'"))
        #expect(result.contains("&lt;script&gt;"))
        #expect(result.contains("&#39;"))
        #expect(result.contains("&quot;"))
    }

    @Test func emptyStringUnchanged() {
        #expect(HTMLEscape.escape("") == "")
    }

    @Test func noSpecialCharsUnchanged() {
        #expect(HTMLEscape.escape("hello world 123") == "hello world 123")
    }

    @Test func doubleEscapingProducesEntities() {
        // Verifies that already-escaped content gets double-escaped
        let result = HTMLEscape.escape("&amp;")
        #expect(result == "&amp;amp;")
    }
}
