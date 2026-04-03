import Testing
@testable import MarkdownRenderer

@Suite struct HTMLTemplateTests {
    @Test func containsDoctype() {
        let html = HTMLTemplate.wrap(body: "<p>hi</p>", theme: .auto, fontSize: .medium)
        #expect(html.hasPrefix("<!DOCTYPE html>"))
    }

    @Test func bodyInjected() {
        let html = HTMLTemplate.wrap(body: "<p>hello</p>", theme: .auto, fontSize: .medium)
        #expect(html.contains("<p>hello</p>"))
    }

    @Test func themeAttributeSet() {
        #expect(HTMLTemplate.wrap(body: "", theme: .light, fontSize: .medium).contains("data-theme=\"light\""))
        #expect(HTMLTemplate.wrap(body: "", theme: .dark, fontSize: .medium).contains("data-theme=\"dark\""))
        #expect(HTMLTemplate.wrap(body: "", theme: .auto, fontSize: .medium).contains("data-theme=\"auto\""))
    }

    @Test func fontSizeInjected() {
        #expect(HTMLTemplate.wrap(body: "", theme: .auto, fontSize: .small).contains("font-size: 13px"))
        #expect(HTMLTemplate.wrap(body: "", theme: .auto, fontSize: .large).contains("font-size: 17px"))
    }

    @Test func sourceBodyClassPresent() {
        let html = HTMLTemplate.wrapSource(body: "<pre><code>hi</code></pre>", fontSize: .medium)
        #expect(html.contains("<body class=\"source\">"))
    }

    @Test func colorSchemeMetaPresent() {
        let html = HTMLTemplate.wrap(body: "", theme: .auto, fontSize: .medium)
        #expect(html.contains("color-scheme"))
    }

    // MARK: - Rich features

    @Test func wrapIncludesInlinedHighlightJS() {
        let html = HTMLTemplate.wrap(body: "", theme: .auto, fontSize: .medium)
        #expect(html.contains("hljs.highlightElement"))
        #expect(html.contains("prefers-color-scheme: light"))
        #expect(html.contains("prefers-color-scheme: dark"))
    }

    @Test func wrapIncludesInlinedKaTeX() {
        let html = HTMLTemplate.wrap(body: "", theme: .auto, fontSize: .medium)
        #expect(html.contains("renderMathInElement"))
        #expect(html.contains(".katex"))
    }

    @Test func wrapIncludesInlinedMermaid() {
        let html = HTMLTemplate.wrap(body: "", theme: .auto, fontSize: .medium)
        #expect(html.contains("mermaid.initialize"))
    }

    @Test func wrapHasNoCDNReferences() {
        let html = HTMLTemplate.wrap(body: "", theme: .auto, fontSize: .medium)
        #expect(!html.contains("cdnjs.cloudflare.com"))
        #expect(!html.contains("cdn.jsdelivr.net"))
    }

    @Test func wrapCombinedIncludesRichFeatures() {
        let html = HTMLTemplate.wrapCombined(
            renderedBody: "<p>hi</p>",
            sourceBody: "<pre><code>hi</code></pre>",
            theme: .auto,
            fontSize: .medium,
            defaultTab: .rendered
        )
        #expect(html.contains("hljs.highlightElement"))
        #expect(html.contains("renderMathInElement"))
        #expect(html.contains("mermaid.initialize"))
    }

    @Test func wrapSourceDoesNotIncludeRichFeatures() {
        let html = HTMLTemplate.wrapSource(body: "<pre><code>hi</code></pre>", fontSize: .medium)
        #expect(!html.contains("hljs"))
        #expect(!html.contains("katex"))
        #expect(!html.contains("mermaid"))
    }

    // MARK: - Combined template

    @Test func wrapCombinedDefaultTabRendered() {
        let html = HTMLTemplate.wrapCombined(
            renderedBody: "<p>rendered</p>",
            sourceBody: "<pre><code>source</code></pre>",
            theme: .auto,
            fontSize: .medium,
            defaultTab: .rendered
        )
        #expect(html.contains("class=\"tab-rendered\""))
        #expect(html.contains("view-rendered"))
        #expect(html.contains("view-source"))
    }

    @Test func wrapCombinedDefaultTabSource() {
        let html = HTMLTemplate.wrapCombined(
            renderedBody: "<p>rendered</p>",
            sourceBody: "<pre><code>source</code></pre>",
            theme: .auto,
            fontSize: .medium,
            defaultTab: .source
        )
        #expect(html.contains("class=\"tab-source\""))
    }

    // MARK: - Frontmatter

    @Test func frontmatterHTMLRendersTable() {
        let html = HTMLTemplate.frontmatterHTML([
            (key: "title", value: "My Doc"),
            (key: "author", value: "Alice")
        ])
        #expect(html.contains("<details class=\"frontmatter\">"))
        #expect(html.contains("Metadata (2)"))
        #expect(html.contains("<th>title</th>"))
        #expect(html.contains("<td>My Doc</td>"))
    }

    @Test func frontmatterHTMLEmptyFieldsReturnsEmpty() {
        let html = HTMLTemplate.frontmatterHTML([])
        #expect(html == "")
    }
}
