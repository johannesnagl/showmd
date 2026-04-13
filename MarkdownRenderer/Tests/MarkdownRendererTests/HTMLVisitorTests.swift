import Testing
import Markdown
@testable import MarkdownRenderer

@Suite struct HTMLVisitorTests {
    private func render(_ markdown: String) -> String {
        let doc = Document(parsing: markdown)
        var visitor = HTMLVisitor()
        return visitor.visit(doc)
    }

    // MARK: - Text & inline

    @Test func plainText() {
        #expect(render("hello") == "<p>hello</p>\n")
    }

    @Test func bold() {
        #expect(render("**bold**").contains("<strong>bold</strong>"))
    }

    @Test func italic() {
        #expect(render("*italic*").contains("<em>italic</em>"))
    }

    @Test func inlineCode() {
        #expect(render("`code`").contains("<code>code</code>"))
    }

    @Test func htmlEscapingInText() {
        let html = render("a < b & c > d")
        #expect(html.contains("&lt;"))
        #expect(html.contains("&amp;"))
        #expect(html.contains("&gt;"))
    }

    @Test func htmlEscapingInInlineCode() {
        #expect(render("`a < b`").contains("&lt;"))
    }

    @Test func link() {
        #expect(render("[text](https://example.com)").contains("<a href=\"https://example.com\">text</a>"))
    }

    @Test func image() {
        let html = render("![alt](image.png)")
        #expect(html.contains("<img"))
        #expect(html.contains("src=\"image.png\""))
        #expect(html.contains("alt=\"alt\""))
    }

    // MARK: - Block elements

    @Test func headings() {
        #expect(render("# H1").contains("<h1>"))
        #expect(render("## H2").contains("<h2>"))
        #expect(render("### H3").contains("<h3>"))
    }

    @Test func codeBlock() {
        let html = render("```\nlet x = 1\n```")
        #expect(html.contains("<pre><code>"))
        #expect(html.contains("let x = 1"))
    }

    @Test func codeBlockWithLanguage() {
        let html = render("```swift\nlet x = 1\n```")
        #expect(html.contains("<code class=\"language-swift\">"))
    }

    @Test func codeBlockHTMLEscaping() {
        #expect(render("```\n<div>\n```").contains("&lt;div&gt;"))
    }

    @Test func mermaidCodeBlock() {
        let html = render("```mermaid\ngraph TD\n  A --> B\n```")
        #expect(html.contains("<pre class=\"mermaid\">"))
        #expect(!html.contains("<code"))
        #expect(html.contains("graph TD"))
    }

    @Test func mermaidCodeBlockEscapesHTML() {
        let html = render("```mermaid\nA --> B[\"<script>\"]\n```")
        #expect(html.contains("&lt;script&gt;"))
    }

    @Test func mathCodeBlock() {
        let html = render("```math\nE = mc^2\n```")
        #expect(html.contains("katex-display"))
        #expect(html.contains("$$"))
        #expect(html.contains("E = mc^2"))
        #expect(!html.contains("<code"))
    }

    @Test func blockquote() {
        let html = render("> quote")
        #expect(html.contains("<blockquote>"))
        #expect(html.contains("quote"))
    }

    @Test func unorderedList() {
        let html = render("- item one\n- item two")
        #expect(html.contains("<ul>"))
        #expect(html.contains("<li>"))
        #expect(html.contains("item one"))
    }

    @Test func orderedList() {
        let html = render("1. first\n2. second")
        #expect(html.contains("<ol>"))
        #expect(html.contains("<li>"))
    }

    @Test func thematicBreak() {
        #expect(render("---").contains("<hr>"))
    }

    // MARK: - GFM: Strikethrough

    @Test func strikethrough() {
        #expect(render("~~strike~~").contains("<del>strike</del>"))
    }

    // MARK: - GFM: Tables

    @Test func tableStructure() {
        let md = """
        | Name | Age |
        |------|-----|
        | Alice | 30 |
        | Bob | 25 |
        """
        let html = render(md)
        #expect(html.contains("<table>"))
        #expect(html.contains("<thead>"))
        #expect(html.contains("<tbody>"))
        #expect(html.contains("<th>Name</th>"))
        #expect(html.contains("<td>Alice</td>"))
    }

    // MARK: - GFM: Task lists

    @Test func uncheckedTaskListItem() {
        let html = render("- [ ] todo")
        #expect(html.contains("<input type=\"checkbox\" disabled>"))
        #expect(html.contains("todo"))
    }

    @Test func checkedTaskListItem() {
        let html = render("- [x] done")
        #expect(html.contains("<input type=\"checkbox\" disabled checked>"))
        #expect(html.contains("done"))
    }

    @Test func taskListItemHasTaskListItemClass() {
        let html = render("- [ ] todo")
        #expect(html.contains("<li class=\"task-list-item\">"))
    }

    @Test func regularListItemHasNoTaskListItemClass() {
        let html = render("- regular item")
        #expect(html.contains("<li>"))
        #expect(!html.contains("task-list-item"))
    }

    @Test func mixedTaskAndRegularListItems() {
        let html = render("- [ ] todo\n- regular\n- [x] done")
        // Task items get the class, regular items do not
        #expect(html.contains("<li class=\"task-list-item\"><input type=\"checkbox\" disabled>"))
        #expect(html.contains("<li class=\"task-list-item\"><input type=\"checkbox\" disabled checked>"))
        #expect(html.contains("<li>"))
    }

    // MARK: - XSS prevention

    @Test func mathCodeBlockEscapesXSS() {
        let html = render("```math\n$$</div><script>alert(1)</script><div>$$\n```")
        #expect(!html.contains("<script>"))
        #expect(html.contains("&lt;script&gt;"))
    }

    @Test func languageAttributeEscapesXSS() {
        let html = render("```\"><script>alert(1)</script>\ncode\n```")
        #expect(!html.contains("<script>alert"))
    }

    @Test func rawHTMLBlockStripsScript() {
        let html = render("<script>alert('xss')</script>")
        #expect(!html.contains("<script>"))
    }

    @Test func rawHTMLBlockStripsIframe() {
        let html = render("<iframe src=\"https://evil.com\"></iframe>")
        #expect(!html.contains("<iframe"))
    }

    @Test func rawHTMLBlockStripsEventHandlers() {
        let html = render("<div onclick=\"alert(1)\">click me</div>")
        #expect(!html.contains("onclick"))
    }

    @Test func rawHTMLBlockStripsJavascriptURL() {
        let html = render("<a href=\"javascript:alert(1)\">link</a>")
        #expect(!html.contains("javascript:"))
    }

    @Test func rawHTMLAllowsSafeTags() {
        let html = render("<div class=\"note\"><strong>Important</strong></div>")
        #expect(html.contains("<div"))
        #expect(html.contains("<strong>"))
    }

    @Test func inlineHTMLStripsScript() {
        let html = render("text <script>alert(1)</script> more")
        #expect(!html.contains("<script>"))
        #expect(html.contains("text"))
    }

    @Test func linkHrefEscapesQuotes() {
        let html = render("[click](https://example.com/\"onmouseover=alert(1))")
        #expect(!html.contains("\"onmouseover"))
        #expect(html.contains("&quot;"))
    }

    @Test func imageAltEscapesHTML() {
        let html = render("![<script>](image.png)")
        #expect(!html.contains("<script>"))
        #expect(html.contains("&lt;script&gt;"))
    }
}
