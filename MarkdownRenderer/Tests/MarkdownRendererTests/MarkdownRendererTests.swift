import Testing
@testable import MarkdownRenderer

@Suite struct MarkdownRendererTests {
    @Test func renderReturnsFullHTMLPage() {
        let html = MarkdownRenderer.render("# Hello", theme: .auto, fontSize: .medium)
        #expect(html.hasPrefix("<!DOCTYPE html>"))
        #expect(html.contains("<h1>"))
        #expect(html.contains("Hello"))
    }

    @Test func renderAppliesTheme() {
        let html = MarkdownRenderer.render("hi", theme: .dark, fontSize: .medium)
        #expect(html.contains("data-theme=\"dark\""))
    }

    @Test func renderAppliesFontSize() {
        let html = MarkdownRenderer.render("hi", theme: .auto, fontSize: .small)
        #expect(html.contains("font-size: 13px"))
    }

    @Test func sourceHTMLEscapesMarkdown() {
        let html = MarkdownRenderer.sourceHTML("# Hello\n**bold**", fontSize: .medium)
        #expect(html.contains("<body class=\"source\">"))
        #expect(html.contains("<pre><code>"))
        #expect(html.contains("# Hello"))
        #expect(!html.contains("<h1>"))
    }

    @Test func sourceHTMLEscapesHTMLEntities() {
        let html = MarkdownRenderer.sourceHTML("<b>raw</b>", fontSize: .medium)
        #expect(html.contains("&lt;b&gt;"))
        #expect(!html.contains("<b>raw</b>"))
    }

    @Test func sourceHTMLEscapesAmpersand() {
        let html = MarkdownRenderer.sourceHTML("a & b", fontSize: .medium)
        #expect(html.contains("&amp;"))
        #expect(!html.contains("a & b"))
    }
}
