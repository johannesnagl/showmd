<p align="center">
  <img src="docs/icon.svg" width="128" height="128" alt="show.md icon">
</p>

<h1 align="center">show.md</h1>

<p align="center">
  <strong>The most readable way to preview any <code>.md</code> file on macOS.</strong><br>
  A free, native Quick Look extension that renders Markdown beautifully — press Space in Finder and go.
</p>

<p align="center">
  <a href="https://show.md">Website</a> &middot;
  <a href="#install">Install</a> &middot;
  <a href="#features">Features</a> &middot;
  <a href="#build-from-source">Build from Source</a>
</p>

---

## Install

```bash
brew install --cask show-md
```

Then open **show.md** once, go to **System Settings → Privacy & Security → Extensions → Quick Look**, and enable it. After that, pressing <kbd>Space</kbd> on any Markdown file in Finder will use show.md automatically.

## Features

- **Full GitHub Flavored Markdown** — tables, task lists, strikethrough, fenced code blocks
- **Syntax highlighting** for 190+ languages (highlight.js, bundled offline)
- **Math rendering** — LaTeX via KaTeX, inline `$...$` and block `$$...$$`
- **Mermaid diagrams** — optional, toggle in settings
- **YAML frontmatter** — parsed and rendered as a collapsible metadata table
- **Emoji shortcodes** — `:rocket:` → 🚀
- **GitHub-style alerts** — `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`
- **Agentic AI XML tags** — `<example>`, `<instructions>`, `<thinking>`, `<context>`, and more rendered as labeled blocks
- **Footnotes, highlight, superscript, subscript, smart quotes**
- **Rendered / Source toggle** — switch between rendered HTML and raw Markdown
- **Copy as HTML** — one click to copy the rendered output
- **Dark mode** — follows macOS appearance, or override in settings (Light / Dark / Auto)
- **Adjustable font size** — Small, Medium, or Large
- **Fully offline** — all JS/CSS dependencies are bundled, no network needed
- **XSS-hardened** — all user content is escaped and raw HTML is sanitized

### Supported file extensions

`.md`, `.markdown`, `.mdx`, `.mdc`, `.rmd`, `.qmd`, `.mdown`, `.mkd`, `.mkdn`, `.mdtext`, `.mdtxt`

## Build from Source

### Prerequisites

- **macOS 26** or later
- **Xcode 16** or later
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** — `brew install xcodegen`

### Steps

```bash
# Clone the repo
git clone https://github.com/johannesnagl/show.md.git
cd show.md

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open show.md.xcodeproj
```

In Xcode:
1. Set your **Development Team** in Signing & Capabilities for both the `ShowMd` and `ShowMdExtension` targets
2. Build and run the `ShowMd` scheme

> The `.xcodeproj` is generated from `project.yml` and excluded from git. Always regenerate it after pulling changes.

### Run tests

```bash
cd MarkdownRenderer
swift test
```

## Architecture

```
show.md/
├── ShowMd/                  # Host app (SwiftUI settings window)
├── ShowMdExtension/         # Quick Look preview extension
├── MarkdownRenderer/        # Swift package (shared between both targets)
│   ├── Sources/
│   │   └── MarkdownRenderer/
│   │       ├── HTMLVisitor.swift       # Markdown → HTML conversion
│   │       ├── HTMLTemplate.swift      # HTML page wrapper + theme
│   │       ├── HTMLPostProcessor.swift # Emoji, footnotes, autolinks, etc.
│   │       ├── HTMLEscape.swift        # XSS prevention
│   │       ├── FrontmatterParser.swift # YAML frontmatter extraction
│   │       ├── ResourceLoader.swift    # Bundled JS/CSS loader
│   │       ├── Settings.swift          # UserDefaults via App Groups
│   │       └── Resources/             # highlight.js, KaTeX, Mermaid (offline)
│   └── Tests/
├── docs/                    # Marketing website (show.md)
└── project.yml              # XcodeGen project definition
```

Settings are shared between the host app and the Quick Look extension via **App Groups** (`group.io.github.show-md`).

## Dependencies

| Dependency | Purpose |
|---|---|
| [apple/swift-markdown](https://github.com/apple/swift-markdown) | Markdown parsing (GFM) |
| [highlight.js](https://highlightjs.org/) | Syntax highlighting (bundled) |
| [KaTeX](https://katex.org/) | Math rendering (bundled) |
| [Mermaid](https://mermaid.js.org/) | Diagram rendering (bundled) |

## License

MIT

## Author

**Johannes Nagl** — [show.md](https://show.md)

Concept, growth, and everything except coding — coded with **Claude**.
