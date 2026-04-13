import Foundation
import Markdown

struct HTMLVisitor: MarkupVisitor {
    typealias Result = String

    private var inTableHead = false

    // Tags allowed through raw HTML passthrough (safe subset)
    private static let allowedTags: Set<String> = [
        "br", "hr", "b", "i", "u", "em", "strong", "del", "s", "ins", "mark",
        "sub", "sup", "small", "big", "abbr", "cite", "q", "dfn", "var", "kbd",
        "samp", "code", "pre", "blockquote", "p", "div", "span", "section",
        "article", "header", "footer", "nav", "aside", "main", "figure",
        "figcaption", "details", "summary", "dl", "dt", "dd", "ul", "ol", "li",
        "table", "thead", "tbody", "tfoot", "tr", "th", "td", "caption",
        "h1", "h2", "h3", "h4", "h5", "h6", "a", "img", "picture", "source",
        "video", "audio", "ruby", "rt", "rp", "wbr", "time", "data",
        "colgroup", "col",
    ]

    // Attributes that can execute code
    private static let dangerousAttrPattern = try! NSRegularExpression(
        pattern: "\\s+on\\w+\\s*=",
        options: .caseInsensitive
    )

    /// Sanitize raw HTML: strip dangerous tags and event-handler attributes.
    private func sanitizeHTML(_ raw: String) -> String {
        var result = raw

        // Strip dangerous tags with content (block-level sanitization)
        let stripPairPatterns = [
            "<script[^>]*>[\\s\\S]*?</script>",
            "<style[^>]*>[\\s\\S]*?</style>",
            "<iframe[^>]*>[\\s\\S]*?</iframe>",
            "<object[^>]*>[\\s\\S]*?</object>",
            "<form[^>]*>[\\s\\S]*?</form>",
            "<textarea[^>]*>[\\s\\S]*?</textarea>",
            "<select[^>]*>[\\s\\S]*?</select>",
            "<button[^>]*>[\\s\\S]*?</button>",
        ]
        for pattern in stripPairPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // Also strip individual opening/closing dangerous tags (handles inline HTML
        // where parser delivers tags separately, e.g. <script> and </script> as two nodes)
        let stripTagPatterns = [
            "</?script[^>]*>",
            "</?style[^>]*>",
            "</?iframe[^>]*>",
            "<iframe[^>]*/>",
            "</?object[^>]*>",
            "<embed[^>]*>",
            "</?form[^>]*>",
            "<input[^>]*>",
            "</?textarea[^>]*>",
            "</?select[^>]*>",
            "</?button[^>]*>",
        ]
        for pattern in stripTagPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // Strip event-handler attributes (on*=) from remaining tags
        let tagRegex = try! NSRegularExpression(pattern: "<([a-zA-Z][a-zA-Z0-9]*)([^>]*)>", options: [])
        let mutableResult = NSMutableString(string: result)
        let tagMatches = tagRegex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
        for match in tagMatches {
            guard let attrsRange = Range(match.range(at: 2), in: result) else { continue }
            let attrs = String(result[attrsRange])
            let range = NSRange(attrs.startIndex..., in: attrs)
            if Self.dangerousAttrPattern.firstMatch(in: attrs, range: range) != nil {
                // Strip all on* attributes
                let cleanAttrs = Self.dangerousAttrPattern.stringByReplacingMatches(
                    in: attrs, range: range, withTemplate: " data-removed="
                )
                mutableResult.replaceCharacters(in: match.range(at: 2), with: cleanAttrs)
            }
        }

        // Also strip javascript: URLs
        return (mutableResult as String).replacingOccurrences(
            of: "javascript:",
            with: "removed:",
            options: .caseInsensitive
        )
    }

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
            return "<div class=\"katex-display\">$$\(escape(codeBlock.code))$$</div>\n"
        }
        let lang = codeBlock.language.map { " class=\"language-\(escape($0))\"" } ?? ""
        return "<pre><code\(lang)>\(escape(codeBlock.code))</code></pre>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr>\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String { sanitizeHTML(html.rawHTML) }
    mutating func visitInlineHTML(_ html: InlineHTML) -> String { sanitizeHTML(html.rawHTML) }

    // MARK: - Lists

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        "<ul>\n\(defaultVisit(unorderedList))</ul>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        "<ol>\n\(defaultVisit(orderedList))</ol>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        var prefix = ""
        var classAttr = ""
        if let checkbox = listItem.checkbox {
            let checked = checkbox == .checked ? " checked" : ""
            prefix = "<input type=\"checkbox\" disabled\(checked)> "
            classAttr = " class=\"task-list-item\""
        }
        return "<li\(classAttr)>\(prefix)\(defaultVisit(listItem))</li>\n"
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
        HTMLEscape.escape(string)
    }
}
