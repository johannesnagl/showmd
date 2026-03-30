import Markdown

public enum MarkdownRenderer {
    public static func render(
        _ markdown: String,
        theme: Settings.Theme,
        fontSize: Settings.FontSize
    ) -> String {
        let document = Document(parsing: markdown)
        var visitor = HTMLVisitor()
        let body = visitor.visit(document)
        return HTMLTemplate.wrap(body: body, theme: theme, fontSize: fontSize)
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
