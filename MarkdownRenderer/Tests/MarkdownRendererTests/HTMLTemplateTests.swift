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
}
