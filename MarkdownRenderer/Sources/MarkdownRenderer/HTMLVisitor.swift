import Markdown

struct HTMLVisitor: MarkupVisitor {
    typealias Result = String

    private var inTableHead = false

    mutating func defaultVisit(_ markup: Markup) -> String {
        markup.children.map { visit($0) }.joined()
    }

    // MARK: - Text & inline

    mutating func visitText(_ text: Text) -> String {
        escape(text.string)
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String { " " }
    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String { "<br>\n" }

    mutating func visitStrong(_ strong: Strong) -> String {
        "<strong>\(defaultVisit(strong))</strong>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        "<em>\(defaultVisit(emphasis))</em>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        "<del>\(defaultVisit(strikethrough))</del>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(escape(inlineCode.code))</code>"
    }

    mutating func visitLink(_ link: Link) -> String {
        let href = escape(link.destination ?? "")
        return "<a href=\"\(href)\">\(defaultVisit(link))</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let src = escape(image.source ?? "")
        let alt = escape(image.plainText)
        return "<img src=\"\(src)\" alt=\"\(alt)\">"
    }

    // MARK: - Block elements

    mutating func visitDocument(_ document: Document) -> String {
        defaultVisit(document)
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        "<p>\(defaultVisit(paragraph))</p>\n"
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let level = heading.level
        return "<h\(level)>\(defaultVisit(heading))</h\(level)>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        "<blockquote>\(defaultVisit(blockQuote))</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        if codeBlock.language == "mermaid" {
            return "<pre class=\"mermaid\">\(escape(codeBlock.code))</pre>\n"
        }
        if codeBlock.language == "math" {
            return "<div class=\"katex-display\">$$\(codeBlock.code)$$</div>\n"
        }
        let lang = codeBlock.language.map { " class=\"language-\($0)\"" } ?? ""
        return "<pre><code\(lang)>\(escape(codeBlock.code))</code></pre>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr>\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String { "" }
    mutating func visitInlineHTML(_ html: InlineHTML) -> String { "" }

    // MARK: - Lists

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        "<ul>\n\(defaultVisit(unorderedList))</ul>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        "<ol>\n\(defaultVisit(orderedList))</ol>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        var prefix = ""
        if let checkbox = listItem.checkbox {
            let checked = checkbox == .checked ? " checked" : ""
            prefix = "<input type=\"checkbox\" disabled\(checked)> "
        }
        return "<li>\(prefix)\(defaultVisit(listItem))</li>\n"
    }

    // MARK: - Tables

    mutating func visitTable(_ table: Table) -> String {
        "<table>\n\(defaultVisit(table))</table>\n"
    }

    mutating func visitTableHead(_ head: Table.Head) -> String {
        inTableHead = true
        let rows = defaultVisit(head)
        inTableHead = false
        return "<thead>\(rows)</thead>\n"
    }

    mutating func visitTableBody(_ body: Table.Body) -> String {
        "<tbody>\(defaultVisit(body))</tbody>\n"
    }

    mutating func visitTableRow(_ row: Table.Row) -> String {
        "<tr>\(defaultVisit(row))</tr>\n"
    }

    mutating func visitTableCell(_ cell: Table.Cell) -> String {
        let tag = inTableHead ? "th" : "td"
        return "<\(tag)>\(defaultVisit(cell))</\(tag)>"
    }

    // MARK: - Helpers

    private func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
