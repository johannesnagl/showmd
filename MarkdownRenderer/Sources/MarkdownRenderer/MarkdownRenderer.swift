import Markdown

public enum MarkdownRenderer {
    public static func render(
        _ markdown: String,
        theme: Settings.Theme,
        fontSize: Settings.FontSize
    ) -> String {
        let fm = FrontmatterParser.parse(markdown)
        let document = Document(parsing: fm.body)
        var visitor = HTMLVisitor()
        let contentBody = HTMLPostProcessor.process(visitor.visit(document))
        let body = HTMLTemplate.frontmatterHTML(fm.fields) + contentBody
        return HTMLTemplate.wrap(body: body, theme: theme, fontSize: fontSize)
    }

    /// Returns only the HTML body content — no wrapping page, no CSS. For clipboard copy.
    public static func renderBody(_ markdown: String) -> String {
        let fm = FrontmatterParser.parse(markdown)
        let document = Document(parsing: fm.body)
        var visitor = HTMLVisitor()
        let contentBody = HTMLPostProcessor.process(visitor.visit(document))
        return HTMLTemplate.frontmatterHTML(fm.fields) + contentBody
    }

    public static func renderCombined(
        _ markdown: String,
        theme: Settings.Theme,
        fontSize: Settings.FontSize,
        defaultTab: Settings.Tab
    ) -> String {
        let fm = FrontmatterParser.parse(markdown)
        let document = Document(parsing: fm.body)
        var visitor = HTMLVisitor()
        let contentBody = HTMLPostProcessor.process(visitor.visit(document))
        let renderedBody = HTMLTemplate.frontmatterHTML(fm.fields) + contentBody
        // Source view shows the full original markdown including frontmatter
        let escaped = markdown
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let sourceBody = "<pre><code>\(escaped)</code></pre>"
        return HTMLTemplate.wrapCombined(
            renderedBody: renderedBody,
            sourceBody: sourceBody,
            theme: theme,
            fontSize: fontSize,
            defaultTab: defaultTab
        )
    }

    public static func sourceHTML(
        _ markdown: String,
        fontSize: Settings.FontSize
    ) -> String {
        let escaped = markdown
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let body = "<pre><code>\(escaped)</code></pre>"
        return HTMLTemplate.wrapSource(body: body, fontSize: fontSize)
    }
}
