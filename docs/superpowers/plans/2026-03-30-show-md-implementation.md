# show.md Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS Quick Look Preview Extension that renders Markdown files with a host app providing settings (theme, font size, default tab) and a "Buy me a pasta" button.

**Architecture:** A local Swift package (`MarkdownRenderer`) contains the rendering pipeline and settings — shared by both the Quick Look extension and the host app via App Groups. The extension uses `QLPreviewingController` + `WKWebView` with a two-segment tab bar. The host app is a fixed-size SwiftUI settings window.

**Tech Stack:** Swift 5.9+, macOS 13+, apple/swift-markdown (SPM), WKWebView, SwiftUI (.formStyle(.grouped)), App Groups (UserDefaults), XcodeGen

---

## File Map

```
show.md/
├── project.yml                             # XcodeGen project spec
├── MarkdownRenderer/                       # Local Swift package
│   ├── Package.swift
│   ├── Sources/MarkdownRenderer/
│   │   ├── Settings.swift                  # UserDefaults wrapper (App Groups)
│   │   ├── HTMLTemplate.swift              # Full HTML page + embedded CSS
│   │   ├── HTMLVisitor.swift               # MarkupVisitor: AST → HTML string
│   │   └── MarkdownRenderer.swift          # Public API: render() + sourceHTML()
│   └── Tests/MarkdownRendererTests/
│       ├── SettingsTests.swift
│       ├── HTMLTemplateTests.swift
│       ├── HTMLVisitorTests.swift
│       └── MarkdownRendererTests.swift
├── ShowMd/                                 # Host app target
│   ├── ShowMdApp.swift
│   ├── ContentView.swift
│   ├── ShowMd.entitlements
│   └── Info.plist
└── ShowMdExtension/                        # Quick Look extension target
    ├── PreviewViewController.swift
    ├── ShowMdExtension.entitlements
    └── Info.plist
```

---

## Task 1: Repository & Swift Package Scaffold

**Files:**
- Create: `MarkdownRenderer/Package.swift`
- Create: `MarkdownRenderer/Sources/MarkdownRenderer/.gitkeep`
- Create: `MarkdownRenderer/Tests/MarkdownRendererTests/.gitkeep`
- Create: `.gitignore`

- [ ] **Step 1: Init git and create gitignore**

```bash
cd /Users/johannesnagl/Code/show.md
git init
cat > .gitignore << 'EOF'
.DS_Store
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/
.build/
DerivedData/
*.ipa
*.dSYM.zip
*.dSYM
EOF
```

- [ ] **Step 2: Create the Swift package directory and Package.swift**

```bash
mkdir -p MarkdownRenderer/Sources/MarkdownRenderer
mkdir -p MarkdownRenderer/Tests/MarkdownRendererTests
```

Write `MarkdownRenderer/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarkdownRenderer",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MarkdownRenderer", targets: ["MarkdownRenderer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.3.0"),
    ],
    targets: [
        .target(
            name: "MarkdownRenderer",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .testTarget(
            name: "MarkdownRendererTests",
            dependencies: ["MarkdownRenderer"]
        ),
    ]
)
```

- [ ] **Step 3: Verify the package resolves**

```bash
cd MarkdownRenderer && swift package resolve
```

Expected: Dependencies downloaded, no errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/johannesnagl/Code/show.md
git add .gitignore MarkdownRenderer/
git commit -m "feat: init repo and MarkdownRenderer Swift package"
```

---

## Task 2: Settings Module

**Files:**
- Create: `MarkdownRenderer/Sources/MarkdownRenderer/Settings.swift`
- Create: `MarkdownRenderer/Tests/MarkdownRendererTests/SettingsTests.swift`

- [ ] **Step 1: Write the failing tests**

Write `MarkdownRenderer/Tests/MarkdownRendererTests/SettingsTests.swift`:

```swift
import XCTest
@testable import MarkdownRenderer

final class SettingsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Settings.userDefaults = UserDefaults(suiteName: "test.settings")!
        Settings.userDefaults.removePersistentDomain(forName: "test.settings")
    }

    func testDefaultTabDefaultsToRendered() {
        XCTAssertEqual(Settings.defaultTab, .rendered)
    }

    func testDefaultTabRoundTrips() {
        Settings.defaultTab = .source
        XCTAssertEqual(Settings.defaultTab, .source)
    }

    func testThemeDefaultsToAuto() {
        XCTAssertEqual(Settings.theme, .auto)
    }

    func testThemeRoundTrips() {
        Settings.theme = .dark
        XCTAssertEqual(Settings.theme, .dark)
    }

    func testFontSizeDefaultsToMedium() {
        XCTAssertEqual(Settings.fontSize, .medium)
    }

    func testFontSizeRoundTrips() {
        Settings.fontSize = .large
        XCTAssertEqual(Settings.fontSize, .large)
    }

    func testFontSizeCSSValues() {
        XCTAssertEqual(Settings.FontSize.small.cssValue, "13px")
        XCTAssertEqual(Settings.FontSize.medium.cssValue, "15px")
        XCTAssertEqual(Settings.FontSize.large.cssValue, "17px")
    }

    func testUnknownRawValueFallsBackToDefault() {
        Settings.userDefaults.set("garbage", forKey: "defaultTab")
        XCTAssertEqual(Settings.defaultTab, .rendered)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd MarkdownRenderer && swift test --filter SettingsTests
```

Expected: FAIL — `Settings` type not found.

- [ ] **Step 3: Implement Settings.swift**

Write `MarkdownRenderer/Sources/MarkdownRenderer/Settings.swift`:

```swift
import Foundation

public struct Settings {
    public static var userDefaults: UserDefaults = UserDefaults(suiteName: "group.io.github.show-md")
        ?? UserDefaults.standard

    public enum Tab: String, CaseIterable {
        case rendered, source
    }

    public enum Theme: String, CaseIterable {
        case auto, light, dark
    }

    public enum FontSize: String, CaseIterable {
        case small, medium, large

        public var cssValue: String {
            switch self {
            case .small:  return "13px"
            case .medium: return "15px"
            case .large:  return "17px"
            }
        }
    }

    public static var defaultTab: Tab {
        get { Tab(rawValue: userDefaults.string(forKey: "defaultTab") ?? "") ?? .rendered }
        set { userDefaults.set(newValue.rawValue, forKey: "defaultTab") }
    }

    public static var theme: Theme {
        get { Theme(rawValue: userDefaults.string(forKey: "theme") ?? "") ?? .auto }
        set { userDefaults.set(newValue.rawValue, forKey: "theme") }
    }

    public static var fontSize: FontSize {
        get { FontSize(rawValue: userDefaults.string(forKey: "fontSize") ?? "") ?? .medium }
        set { userDefaults.set(newValue.rawValue, forKey: "fontSize") }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd MarkdownRenderer && swift test --filter SettingsTests
```

Expected: All 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/johannesnagl/Code/show.md
git add MarkdownRenderer/Sources/MarkdownRenderer/Settings.swift \
        MarkdownRenderer/Tests/MarkdownRendererTests/SettingsTests.swift
git commit -m "feat: add Settings module with App Groups UserDefaults"
```

---

## Task 3: HTML Template & CSS

**Files:**
- Create: `MarkdownRenderer/Sources/MarkdownRenderer/HTMLTemplate.swift`
- Create: `MarkdownRenderer/Tests/MarkdownRendererTests/HTMLTemplateTests.swift`

- [ ] **Step 1: Write the failing tests**

Write `MarkdownRenderer/Tests/MarkdownRendererTests/HTMLTemplateTests.swift`:

```swift
import XCTest
@testable import MarkdownRenderer

final class HTMLTemplateTests: XCTestCase {
    func testContainsDoctype() {
        let html = HTMLTemplate.wrap(body: "<p>hi</p>", theme: .auto, fontSize: .medium)
        XCTAssertTrue(html.hasPrefix("<!DOCTYPE html>"))
    }

    func testBodyInjected() {
        let html = HTMLTemplate.wrap(body: "<p>hello</p>", theme: .auto, fontSize: .medium)
        XCTAssertTrue(html.contains("<p>hello</p>"))
    }

    func testThemeAttributeSet() {
        let light = HTMLTemplate.wrap(body: "", theme: .light, fontSize: .medium)
        XCTAssertTrue(light.contains("data-theme=\"light\""))

        let dark = HTMLTemplate.wrap(body: "", theme: .dark, fontSize: .medium)
        XCTAssertTrue(dark.contains("data-theme=\"dark\""))

        let auto = HTMLTemplate.wrap(body: "", theme: .auto, fontSize: .medium)
        XCTAssertTrue(auto.contains("data-theme=\"auto\""))
    }

    func testFontSizeInjected() {
        let small = HTMLTemplate.wrap(body: "", theme: .auto, fontSize: .small)
        XCTAssertTrue(small.contains("font-size: 13px"))

        let large = HTMLTemplate.wrap(body: "", theme: .auto, fontSize: .large)
        XCTAssertTrue(large.contains("font-size: 17px"))
    }

    func testSourceBodyClassPresent() {
        let html = HTMLTemplate.wrapSource(body: "<pre><code>hi</code></pre>", fontSize: .medium)
        XCTAssertTrue(html.contains("<body class=\"source\">"))
    }

    func testColorSchemeMetaPresent() {
        let html = HTMLTemplate.wrap(body: "", theme: .auto, fontSize: .medium)
        XCTAssertTrue(html.contains("color-scheme"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd MarkdownRenderer && swift test --filter HTMLTemplateTests
```

Expected: FAIL — `HTMLTemplate` not found.

- [ ] **Step 3: Implement HTMLTemplate.swift**

Write `MarkdownRenderer/Sources/MarkdownRenderer/HTMLTemplate.swift`:

```swift
public enum HTMLTemplate {
    public static func wrap(body: String, theme: Settings.Theme, fontSize: Settings.FontSize) -> String {
        """
        <!DOCTYPE html>
        <html data-theme="\(theme.rawValue)" style="font-size: \(fontSize.cssValue)">
        <head>
          <meta charset="UTF-8">
          <meta name="color-scheme" content="light dark">
          <style>\(css)</style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    public static func wrapSource(body: String, fontSize: Settings.FontSize) -> String {
        """
        <!DOCTYPE html>
        <html data-theme="auto" style="font-size: \(fontSize.cssValue)">
        <head>
          <meta charset="UTF-8">
          <meta name="color-scheme" content="light dark">
          <style>\(css)</style>
        </head>
        <body class="source">
        \(body)
        </body>
        </html>
        """
    }

    static let css = """
        :root {
          --bg: #ffffff;
          --text: #1a1a1a;
          --code-bg: #f5f5f5;
          --border: #d0d0d0;
          --link: #0066cc;
          --table-alt: #f9f9f9;
        }
        @media (prefers-color-scheme: dark) {
          :root {
            --bg: #1e1e1e;
            --text: #e8e8e8;
            --code-bg: #2a2a2a;
            --border: #3a3a3a;
            --link: #4da6ff;
            --table-alt: #252525;
          }
        }
        [data-theme="light"] {
          --bg: #ffffff; --text: #1a1a1a; --code-bg: #f5f5f5;
          --border: #d0d0d0; --link: #0066cc; --table-alt: #f9f9f9;
        }
        [data-theme="dark"] {
          --bg: #1e1e1e; --text: #e8e8e8; --code-bg: #2a2a2a;
          --border: #3a3a3a; --link: #4da6ff; --table-alt: #252525;
        }
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        html { background: var(--bg); }
        body {
          background: var(--bg);
          color: var(--text);
          font-family: -apple-system, BlinkMacSystemFont, sans-serif;
          line-height: 1.6;
          padding: 24px 32px;
          max-width: 800px;
          margin: 0 auto;
        }
        h1, h2, h3, h4, h5, h6 {
          margin-top: 24px;
          margin-bottom: 8px;
          font-weight: 600;
          line-height: 1.25;
        }
        h1 { font-size: 1.6em; }
        h2 { font-size: 1.35em; }
        h3 { font-size: 1.15em; }
        h4, h5, h6 { font-size: 1em; }
        p { margin-bottom: 16px; }
        a { color: var(--link); pointer-events: none; text-decoration: none; }
        code {
          font-family: ui-monospace, SFMono-Regular, monospace;
          font-size: 0.875em;
          background: var(--code-bg);
          border-radius: 4px;
          padding: 2px 5px;
        }
        pre {
          background: var(--code-bg);
          border-radius: 6px;
          padding: 16px;
          overflow-x: auto;
          margin-bottom: 16px;
        }
        pre code { background: none; padding: 0; border-radius: 0; }
        blockquote {
          border-left: 3px solid var(--border);
          padding-left: 16px;
          margin: 0 0 16px 0;
          opacity: 0.8;
        }
        ul, ol { padding-left: 24px; margin-bottom: 16px; }
        li { margin-bottom: 4px; }
        li input[type="checkbox"] { margin-right: 6px; }
        hr { border: none; border-top: 1px solid var(--border); margin: 24px 0; }
        table {
          border-collapse: collapse;
          width: 100%;
          margin-bottom: 16px;
          font-size: 0.9em;
        }
        th, td { border: 1px solid var(--border); padding: 8px 12px; text-align: left; }
        th { background: var(--code-bg); font-weight: 600; }
        tr:nth-child(even) td { background: var(--table-alt); }
        img { max-width: 100%; height: auto; }
        del { text-decoration: line-through; opacity: 0.7; }
        body.source { padding: 16px; max-width: none; }
        body.source pre {
          margin: 0;
          word-wrap: break-word;
          white-space: pre-wrap;
          font-size: 1em;
          border-radius: 0;
          padding: 0;
          background: none;
        }
        """
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd MarkdownRenderer && swift test --filter HTMLTemplateTests
```

Expected: All 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/johannesnagl/Code/show.md
git add MarkdownRenderer/Sources/MarkdownRenderer/HTMLTemplate.swift \
        MarkdownRenderer/Tests/MarkdownRendererTests/HTMLTemplateTests.swift
git commit -m "feat: add HTMLTemplate with full CSS theming"
```

---

## Task 4: HTMLVisitor — Inline & Basic Block Elements

**Files:**
- Create: `MarkdownRenderer/Sources/MarkdownRenderer/HTMLVisitor.swift`
- Create: `MarkdownRenderer/Tests/MarkdownRendererTests/HTMLVisitorTests.swift`

- [ ] **Step 1: Write the failing tests (inline & basic block)**

Write `MarkdownRenderer/Tests/MarkdownRendererTests/HTMLVisitorTests.swift`:

```swift
import XCTest
import Markdown
@testable import MarkdownRenderer

final class HTMLVisitorTests: XCTestCase {
    private func render(_ markdown: String) -> String {
        let doc = Document(parsing: markdown)
        var visitor = HTMLVisitor()
        return visitor.visit(doc)
    }

    // MARK: - Text & inline

    func testPlainText() {
        XCTAssertEqual(render("hello"), "<p>hello</p>\n")
    }

    func testBold() {
        XCTAssertTrue(render("**bold**").contains("<strong>bold</strong>"))
    }

    func testItalic() {
        XCTAssertTrue(render("*italic*").contains("<em>italic</em>"))
    }

    func testInlineCode() {
        XCTAssertTrue(render("`code`").contains("<code>code</code>"))
    }

    func testHTMLEscapingInText() {
        let html = render("a < b & c > d")
        XCTAssertTrue(html.contains("&lt;"))
        XCTAssertTrue(html.contains("&amp;"))
        XCTAssertTrue(html.contains("&gt;"))
    }

    func testHTMLEscapingInInlineCode() {
        let html = render("`a < b`")
        XCTAssertTrue(html.contains("&lt;"))
    }

    func testLink() {
        let html = render("[text](https://example.com)")
        XCTAssertTrue(html.contains("<a href=\"https://example.com\">text</a>"))
    }

    func testImage() {
        let html = render("![alt](image.png)")
        XCTAssertTrue(html.contains("<img"))
        XCTAssertTrue(html.contains("src=\"image.png\""))
        XCTAssertTrue(html.contains("alt=\"alt\""))
    }

    // MARK: - Block elements

    func testHeadings() {
        XCTAssertTrue(render("# H1").contains("<h1>"))
        XCTAssertTrue(render("## H2").contains("<h2>"))
        XCTAssertTrue(render("### H3").contains("<h3>"))
    }

    func testCodeBlock() {
        let html = render("```\nlet x = 1\n```")
        XCTAssertTrue(html.contains("<pre><code>"))
        XCTAssertTrue(html.contains("let x = 1"))
    }

    func testCodeBlockHTMLEscaping() {
        let html = render("```\n<div>\n```")
        XCTAssertTrue(html.contains("&lt;div&gt;"))
    }

    func testBlockquote() {
        let html = render("> quote")
        XCTAssertTrue(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("quote"))
    }

    func testUnorderedList() {
        let html = render("- item one\n- item two")
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<li>"))
        XCTAssertTrue(html.contains("item one"))
    }

    func testOrderedList() {
        let html = render("1. first\n2. second")
        XCTAssertTrue(html.contains("<ol>"))
        XCTAssertTrue(html.contains("<li>"))
    }

    func testThematicBreak() {
        XCTAssertTrue(render("---").contains("<hr>"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd MarkdownRenderer && swift test --filter HTMLVisitorTests
```

Expected: FAIL — `HTMLVisitor` not found.

- [ ] **Step 3: Implement HTMLVisitor.swift (inline & basic block)**

Write `MarkdownRenderer/Sources/MarkdownRenderer/HTMLVisitor.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd MarkdownRenderer && swift test --filter HTMLVisitorTests
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/johannesnagl/Code/show.md
git add MarkdownRenderer/Sources/MarkdownRenderer/HTMLVisitor.swift \
        MarkdownRenderer/Tests/MarkdownRendererTests/HTMLVisitorTests.swift
git commit -m "feat: add HTMLVisitor covering all GFM elements"
```

---

## Task 5: HTMLVisitor — GFM Elements Tests

**Files:**
- Modify: `MarkdownRenderer/Tests/MarkdownRendererTests/HTMLVisitorTests.swift`

- [ ] **Step 1: Add GFM tests to HTMLVisitorTests.swift**

Append these test methods to `HTMLVisitorTests` (inside the class, before the closing `}`):

```swift
    // MARK: - GFM: Strikethrough

    func testStrikethrough() {
        let html = render("~~strike~~")
        XCTAssertTrue(html.contains("<del>strike</del>"))
    }

    // MARK: - GFM: Tables

    func testTableHasCorrectStructure() {
        let md = """
        | Name | Age |
        |------|-----|
        | Alice | 30 |
        | Bob | 25 |
        """
        let html = render(md)
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<thead>"))
        XCTAssertTrue(html.contains("<tbody>"))
        XCTAssertTrue(html.contains("<th>Name</th>"))
        XCTAssertTrue(html.contains("<td>Alice</td>"))
    }

    // MARK: - GFM: Task lists

    func testUncheckedTaskListItem() {
        let html = render("- [ ] todo")
        XCTAssertTrue(html.contains("<input type=\"checkbox\" disabled>"))
        XCTAssertTrue(html.contains("todo"))
    }

    func testCheckedTaskListItem() {
        let html = render("- [x] done")
        XCTAssertTrue(html.contains("<input type=\"checkbox\" disabled checked>"))
        XCTAssertTrue(html.contains("done"))
    }
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
cd MarkdownRenderer && swift test --filter HTMLVisitorTests
```

Expected: All tests PASS (strikethrough, tables, task lists handled in Task 4's implementation).

- [ ] **Step 3: Commit**

```bash
cd /Users/johannesnagl/Code/show.md
git add MarkdownRenderer/Tests/MarkdownRendererTests/HTMLVisitorTests.swift
git commit -m "test: add GFM coverage (tables, task lists, strikethrough)"
```

---

## Task 6: MarkdownRenderer Public API

**Files:**
- Create: `MarkdownRenderer/Sources/MarkdownRenderer/MarkdownRenderer.swift`
- Create: `MarkdownRenderer/Tests/MarkdownRendererTests/MarkdownRendererTests.swift`

- [ ] **Step 1: Write the failing tests**

Write `MarkdownRenderer/Tests/MarkdownRendererTests/MarkdownRendererTests.swift`:

```swift
import XCTest
@testable import MarkdownRenderer

final class MarkdownRendererTests: XCTestCase {
    func testRenderReturnsFullHTMLPage() {
        let html = MarkdownRenderer.render("# Hello", theme: .auto, fontSize: .medium)
        XCTAssertTrue(html.hasPrefix("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("<h1>"))
        XCTAssertTrue(html.contains("Hello"))
    }

    func testRenderAppliesTheme() {
        let html = MarkdownRenderer.render("hi", theme: .dark, fontSize: .medium)
        XCTAssertTrue(html.contains("data-theme=\"dark\""))
    }

    func testRenderAppliesFontSize() {
        let html = MarkdownRenderer.render("hi", theme: .auto, fontSize: .small)
        XCTAssertTrue(html.contains("font-size: 13px"))
    }

    func testSourceHTMLEscapesMarkdown() {
        let html = MarkdownRenderer.sourceHTML("# Hello\n**bold**", fontSize: .medium)
        XCTAssertTrue(html.contains("<body class=\"source\">"))
        XCTAssertTrue(html.contains("<pre><code>"))
        XCTAssertTrue(html.contains("# Hello"))
        XCTAssertFalse(html.contains("<h1>"))
    }

    func testSourceHTMLEscapesHTMLEntities() {
        let html = MarkdownRenderer.sourceHTML("<b>raw</b>", fontSize: .medium)
        XCTAssertTrue(html.contains("&lt;b&gt;"))
        XCTAssertFalse(html.contains("<b>raw</b>"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd MarkdownRenderer && swift test --filter MarkdownRendererTests
```

Expected: FAIL — `MarkdownRenderer` type not found.

- [ ] **Step 3: Implement MarkdownRenderer.swift**

Write `MarkdownRenderer/Sources/MarkdownRenderer/MarkdownRenderer.swift`:

```swift
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
```

- [ ] **Step 4: Run all package tests**

```bash
cd MarkdownRenderer && swift test
```

Expected: All tests PASS across all test targets.

- [ ] **Step 5: Commit**

```bash
cd /Users/johannesnagl/Code/show.md
git add MarkdownRenderer/Sources/MarkdownRenderer/MarkdownRenderer.swift \
        MarkdownRenderer/Tests/MarkdownRendererTests/MarkdownRendererTests.swift
git commit -m "feat: add public MarkdownRenderer API (render + sourceHTML)"
```

---

## Task 7: Xcode Project Setup (XcodeGen)

**Files:**
- Create: `project.yml`
- Create: `ShowMd/ShowMdApp.swift` (stub)
- Create: `ShowMd/ContentView.swift` (stub)
- Create: `ShowMd/Info.plist`
- Create: `ShowMd/ShowMd.entitlements`
- Create: `ShowMdExtension/PreviewViewController.swift` (stub)
- Create: `ShowMdExtension/Info.plist`
- Create: `ShowMdExtension/ShowMdExtension.entitlements`

- [ ] **Step 1: Install XcodeGen**

```bash
brew install xcodegen
```

Expected: `xcodegen version 2.x.x` when done.

- [ ] **Step 2: Create target source directories**

```bash
mkdir -p ShowMd ShowMdExtension
```

- [ ] **Step 3: Create stub source files**

Write `ShowMd/ShowMdApp.swift`:

```swift
import SwiftUI

@main
struct ShowMdApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Write `ShowMd/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("show.md")
    }
}
```

Write `ShowMdExtension/PreviewViewController.swift`:

```swift
import Cocoa
import Quartz

class PreviewViewController: NSViewController, QLPreviewingController {
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        handler(nil)
    }
}
```

- [ ] **Step 4: Create entitlements files**

Write `ShowMd/ShowMd.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.io.github.show-md</string>
    </array>
</dict>
</plist>
```

Write `ShowMdExtension/ShowMdExtension.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.io.github.show-md</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 5: Create Info.plist files**

Write `ShowMd/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>show.md</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHumanReadableCopyright</key>
    <string></string>
</dict>
</plist>
```

Write `ShowMdExtension/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>QLSupportedContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
                <string>public.markdown</string>
            </array>
            <key>QLSupportsSearchableItems</key>
            <false/>
        </dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.quicklook.preview</string>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).PreviewViewController</string>
    </dict>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
```

- [ ] **Step 6: Write project.yml**

> **Important:** Replace `YOUR_TEAM_ID` with your actual Apple Developer Team ID throughout this file before generating.

Write `project.yml`:

```yaml
name: show.md
options:
  bundleIdPrefix: io.github
  deploymentTarget:
    macOS: "13.0"
  createIntermediateGroups: true

packages:
  MarkdownRenderer:
    path: MarkdownRenderer

targets:
  ShowMd:
    type: application
    platform: macOS
    sources:
      - ShowMd
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: io.github.show-md
        PRODUCT_NAME: show.md
        MACOSX_DEPLOYMENT_TARGET: "13.0"
        ENABLE_HARDENED_RUNTIME: YES
        CODE_SIGN_IDENTITY: "Developer ID Application"
        DEVELOPMENT_TEAM: YOUR_TEAM_ID
        INFOPLIST_FILE: ShowMd/Info.plist
    entitlements:
      path: ShowMd/ShowMd.entitlements
    dependencies:
      - package: MarkdownRenderer
      - target: ShowMdExtension
        embed: true

  ShowMdExtension:
    type: app-extension
    platform: macOS
    sources:
      - ShowMdExtension
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: io.github.show-md.extension
        MACOSX_DEPLOYMENT_TARGET: "13.0"
        CODE_SIGN_IDENTITY: "Developer ID Application"
        DEVELOPMENT_TEAM: YOUR_TEAM_ID
        INFOPLIST_FILE: ShowMdExtension/Info.plist
    entitlements:
      path: ShowMdExtension/ShowMdExtension.entitlements
    dependencies:
      - package: MarkdownRenderer
```

- [ ] **Step 7: Generate the Xcode project**

```bash
cd /Users/johannesnagl/Code/show.md
xcodegen generate
```

Expected: `show.md.xcodeproj` created, no errors.

- [ ] **Step 8: Verify build**

Open the project in Xcode and build both targets (Cmd+B). Fix any configuration issues before continuing.

```bash
open show.md.xcodeproj
```

Expected: Both targets build successfully.

- [ ] **Step 9: Commit**

```bash
git add project.yml ShowMd/ ShowMdExtension/
git commit -m "feat: add XcodeGen project spec and target stubs"
```

> **Note:** Add `*.xcodeproj` to `.gitignore` if you prefer to generate it from `project.yml` on each checkout:
> ```bash
> echo "show.md.xcodeproj/" >> .gitignore
> ```

---

## Task 8: Quick Look Extension — PreviewViewController

**Files:**
- Modify: `ShowMdExtension/PreviewViewController.swift`

- [ ] **Step 1: Implement PreviewViewController**

Overwrite `ShowMdExtension/PreviewViewController.swift`:

```swift
import Cocoa
import Quartz
import WebKit
import MarkdownRenderer

class PreviewViewController: NSViewController, QLPreviewingController {
    private var webView: WKWebView!
    private var segmentedControl: NSSegmentedControl!
    private var markdownSource = ""
    private var currentTab: Settings.Tab = Settings.defaultTab

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        segmentedControl = NSSegmentedControl(
            labels: ["Rendered", "Source"],
            trackingMode: .selectOne,
            target: self,
            action: #selector(tabChanged(_:))
        )
        segmentedControl.selectedSegment = currentTab == .rendered ? 0 : 1
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(segmentedControl)
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            segmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            webView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        currentTab = Settings.defaultTab
        segmentedControl?.selectedSegment = currentTab == .rendered ? 0 : 1
        do {
            markdownSource = try String(contentsOf: url, encoding: .utf8)
            loadCurrentTab()
            handler(nil)
        } catch {
            handler(error)
        }
    }

    @objc private func tabChanged(_ sender: NSSegmentedControl) {
        currentTab = sender.selectedSegment == 0 ? .rendered : .source
        loadCurrentTab()
    }

    private func loadCurrentTab() {
        let html: String
        switch currentTab {
        case .rendered:
            html = MarkdownRenderer.render(
                markdownSource,
                theme: Settings.theme,
                fontSize: Settings.fontSize
            )
        case .source:
            html = MarkdownRenderer.sourceHTML(
                markdownSource,
                fontSize: Settings.fontSize
            )
        }
        webView.loadHTMLString(html, baseURL: nil)
    }
}
```

- [ ] **Step 2: Build the extension target in Xcode**

In Xcode, select the `ShowMdExtension` scheme and build (Cmd+B).

Expected: Builds with no errors.

- [ ] **Step 3: Manual test — Quick Look preview**

1. Build and run the `ShowMd` scheme (Cmd+R) — this installs the extension.
2. Open System Settings → Privacy & Security → Extensions → Quick Look.
3. Enable "show.md".
4. In Finder, select any `.md` file and press Space.

Expected: Quick Look shows rendered markdown with a "Rendered / Source" toggle at the top.

- [ ] **Step 4: Commit**

```bash
cd /Users/johannesnagl/Code/show.md
git add ShowMdExtension/PreviewViewController.swift
git commit -m "feat: implement Quick Look PreviewViewController with tab bar"
```

---

## Task 9: Host App — ContentView & Settings UI

**Files:**
- Modify: `ShowMd/ShowMdApp.swift`
- Modify: `ShowMd/ContentView.swift`

- [ ] **Step 1: Implement ShowMdApp.swift**

Overwrite `ShowMd/ShowMdApp.swift`:

```swift
import SwiftUI

@main
struct ShowMdApp: App {
    var body: some Scene {
        WindowGroup("show.md") {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 420)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
```

- [ ] **Step 2: Implement ContentView.swift**

Overwrite `ShowMd/ContentView.swift`:

```swift
import SwiftUI
import MarkdownRenderer

struct ContentView: View {
    @State private var defaultTab: Settings.Tab = Settings.defaultTab
    @State private var theme: Settings.Theme = Settings.theme
    @State private var fontSize: Settings.FontSize = Settings.fontSize

    var body: some View {
        VStack(spacing: 0) {
            headerView
            formView
            footerView
        }
        .onChange(of: defaultTab) { Settings.defaultTab = $0 }
        .onChange(of: theme)      { Settings.theme = $0 }
        .onChange(of: fontSize)   { Settings.fontSize = $0 }
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            Text("show.md")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Quick Look preview for Markdown files")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private var formView: some View {
        Form {
            Section("Preview") {
                HStack {
                    Text("Quick Look Extension")
                    Spacer()
                    Button("Open in System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.link)
                }

                Picker("Default Tab", selection: $defaultTab) {
                    Text("Rendered").tag(Settings.Tab.rendered)
                    Text("Source").tag(Settings.Tab.source)
                }
                .pickerStyle(.segmented)
            }

            Section("Appearance") {
                Picker("Theme", selection: $theme) {
                    Text("Auto").tag(Settings.Theme.auto)
                    Text("Light").tag(Settings.Theme.light)
                    Text("Dark").tag(Settings.Theme.dark)
                }
                .pickerStyle(.segmented)

                Picker("Font Size", selection: $fontSize) {
                    Text("Small").tag(Settings.FontSize.small)
                    Text("Medium").tag(Settings.FontSize.medium)
                    Text("Large").tag(Settings.FontSize.large)
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }

    private var footerView: some View {
        HStack(spacing: 16) {
            Button("Buy me a pasta ☕") {
                if let url = URL(string: "https://buymeacoffee.com/YOUR_USERNAME") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)

            Button("GitHub") {
                if let url = URL(string: "https://github.com/YOUR_USERNAME/show.md") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
        }
        .font(.caption)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
}
```

> **Note:** Replace `YOUR_USERNAME` in the two URL strings with your actual username before shipping.

- [ ] **Step 3: Add CFBundleShortVersionString to ShowMd/Info.plist**

Add these two keys to `ShowMd/Info.plist` inside the root `<dict>`:

```xml
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
```

- [ ] **Step 4: Build and manually test the host app**

Build and run the `ShowMd` scheme in Xcode (Cmd+R).

Expected:
- Window shows app icon, title, tagline, version
- "Preview" section has "Open in System Settings" button + Default Tab picker
- "Appearance" section has Theme and Font Size pickers
- Footer shows "Buy me a pasta ☕" and "GitHub" link buttons
- Changing settings persists across app restarts
- Quick Look preview reflects updated settings immediately

- [ ] **Step 5: Commit**

```bash
cd /Users/johannesnagl/Code/show.md
git add ShowMd/ShowMdApp.swift ShowMd/ContentView.swift ShowMd/Info.plist
git commit -m "feat: implement host app settings UI with SwiftUI formStyle grouped"
```

---

## Task 10: Manual Integration Testing

No automated tests for this task — Quick Look extensions require manual verification.

- [ ] **Step 1: Test basic rendering**

Create a test file `test.md`:

```markdown
# Heading 1
## Heading 2

Normal paragraph with **bold**, *italic*, and `inline code`.

> A blockquote

---

- Item one
- Item two
  - Nested item

1. First
2. Second
```

Open in Finder → press Space. Verify rendered output matches expected HTML.

- [ ] **Step 2: Test GFM features**

Create `test-gfm.md`:

```markdown
## Table

| Name  | Role     |
|-------|----------|
| Alice | Engineer |
| Bob   | Designer |

## Task list

- [x] Done item
- [ ] Todo item

## Strikethrough

~~deleted text~~
```

Open in Finder → press Space. Verify table renders with borders, checkboxes are visible, strikethrough works.

- [ ] **Step 3: Test source tab**

With any `.md` file open in Quick Look, click "Source". Verify raw markdown is shown in monospace, HTML entities are escaped, no rendering artifacts.

- [ ] **Step 4: Test theme switching**

In the host app, change Theme to "Dark". Open Quick Look on a `.md` file. Verify dark background and light text.

Change to "Light". Verify light theme regardless of macOS system appearance.

Change to "Auto". Verify it follows macOS system appearance.

- [ ] **Step 5: Test font size**

Change Font Size to "Small". Verify text is smaller in Quick Look.
Change to "Large". Verify text is larger.

- [ ] **Step 6: Test default tab persistence**

Set Default Tab to "Source". Close and re-open Quick Look on a `.md` file. Verify Source tab is selected by default.

---

## Task 11: Release Prep & Notarization

- [ ] **Step 1: Archive the app**

In Xcode: Product → Archive.

Wait for archive to complete. Xcode Organizer opens automatically.

- [ ] **Step 2: Export for Developer ID distribution**

In Xcode Organizer:
1. Select the archive → Distribute App
2. Choose "Direct Distribution" (Developer ID)
3. Export to a folder, e.g., `~/Desktop/show-md-export/`

- [ ] **Step 3: Zip for notarization**

```bash
ditto -c -k --sequesterRsrc --keepParent \
  ~/Desktop/show-md-export/show.md.app \
  ~/Desktop/show.md.zip
```

- [ ] **Step 4: Submit for notarization**

```bash
xcrun notarytool submit ~/Desktop/show.md.zip \
  --apple-id YOUR_APPLE_ID \
  --team-id YOUR_TEAM_ID \
  --password YOUR_APP_SPECIFIC_PASSWORD \
  --wait
```

Expected: `status: Accepted`

- [ ] **Step 5: Staple the notarization ticket**

```bash
xcrun stapler staple ~/Desktop/show-md-export/show.md.app
```

Expected: `The staple and validate action worked!`

- [ ] **Step 6: Repackage the stapled app**

```bash
ditto -c -k --sequesterRsrc --keepParent \
  ~/Desktop/show-md-export/show.md.app \
  ~/Desktop/show.md-1.0.0.zip
```

- [ ] **Step 7: Generate checksum**

```bash
shasum -a 256 ~/Desktop/show.md-1.0.0.zip > ~/Desktop/show.md-1.0.0.zip.sha256
cat ~/Desktop/show.md-1.0.0.zip.sha256
```

Note the SHA256 hash — you'll need it for the Homebrew cask.

- [ ] **Step 8: Create GitHub release**

Tag and push:

```bash
git tag v1.0.0
git push origin main --tags
```

Create release on GitHub with `show.md-1.0.0.zip` and `show.md-1.0.0.zip.sha256` as assets.

---

## Task 12: Homebrew Cask

- [ ] **Step 1: Create personal tap (if not already done)**

```bash
gh repo create homebrew-tap --public --description "Homebrew tap for show.md"
brew tap YOUR_USERNAME/tap https://github.com/YOUR_USERNAME/homebrew-tap
```

- [ ] **Step 2: Write the cask formula**

In the `homebrew-tap` repo, create `Casks/show-md.rb`:

```ruby
cask "show-md" do
  version "1.0.0"
  sha256 "PASTE_SHA256_FROM_TASK_11_STEP_7_HERE"

  url "https://github.com/YOUR_USERNAME/show.md/releases/download/v#{version}/show.md-#{version}.zip"
  name "show.md"
  desc "Quick Look extension for Markdown files"
  homepage "https://github.com/YOUR_USERNAME/show.md"

  app "show.md.app"

  zap trash: [
    "~/Library/Preferences/group.io.github.show-md.plist",
  ]
end
```

- [ ] **Step 3: Test the cask locally**

```bash
brew install --cask YOUR_USERNAME/tap/show-md
```

Expected: show.md.app installed in /Applications.

- [ ] **Step 4: Verify uninstall**

```bash
brew uninstall --cask show-md
```

Expected: App removed. After running `brew uninstall --zap show-md`, the preferences plist is also removed.

- [ ] **Step 5: Commit cask**

```bash
cd homebrew-tap
git add Casks/show-md.rb
git commit -m "feat: add show-md cask v1.0.0"
git push
```
