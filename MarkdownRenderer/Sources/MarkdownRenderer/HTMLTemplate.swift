public enum HTMLTemplate {
    public static func wrap(body: String, theme: Settings.Theme, fontSize: Settings.FontSize, mermaid: Bool = false) -> String {
        """
        <!DOCTYPE html>
        <html data-theme="\(theme.rawValue)" style="font-size: \(fontSize.cssValue)">
        <head>
          <meta charset="UTF-8">
          <meta name="color-scheme" content="light dark">
          <style>\(css)</style>
          \(richFeatureHead)
        </head>
        <body>
        \(body)
        \(richFeatureScripts(mermaid: mermaid))
        </body>
        </html>
        """
    }

    public static func wrapCombined(
        renderedBody: String,
        sourceBody: String,
        theme: Settings.Theme,
        fontSize: Settings.FontSize,
        defaultTab: Settings.Tab,
        mermaid: Bool = false
    ) -> String {
        let initialClass = defaultTab == .rendered ? "tab-rendered" : "tab-source"
        return """
        <!DOCTYPE html>
        <html data-theme="\(theme.rawValue)" class="\(initialClass)" style="font-size: \(fontSize.cssValue)">
        <head>
          <meta charset="UTF-8">
          <meta name="color-scheme" content="light dark">
          <style>
        \(css)
          html.tab-source  .view-rendered { display: none; }
          html.tab-rendered .view-source  { display: none; }
          .view-source { padding: 16px; }
          .view-source pre {
            margin: 0; word-wrap: break-word; white-space: pre-wrap;
            font-size: 1em; border-radius: 0; padding: 0; background: none;
          }
          </style>
          \(richFeatureHead)
        </head>
        <body>
          <div class="view-rendered">\(renderedBody)</div>
          <div class="view-source">\(sourceBody)</div>
        \(richFeatureScripts(mermaid: mermaid))
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

    static func frontmatterHTML(_ fields: [(key: String, value: String)]) -> String {
        guard !fields.isEmpty else { return "" }
        let rows = fields.map { field in
            "<tr><th>\(HTMLEscape.escape(field.key))</th><td>\(HTMLEscape.escape(field.value))</td></tr>"
        }.joined(separator: "\n")
        let count = fields.count
        return """
        <details class="frontmatter">
          <summary>Metadata (\(count)) — YAML Frontmatter</summary>
          <table>\(rows)</table>
        </details>
        """
    }

    // MARK: - Rich features (syntax highlighting, math, diagrams)

    private static var richFeatureHead: String {
        """
        <!-- Syntax Highlighting -->
        <style media="(prefers-color-scheme: light)">\(ResourceLoader.highlightLightCSS)</style>
        <style media="(prefers-color-scheme: dark)">\(ResourceLoader.highlightDarkCSS)</style>
        <style>
          [data-theme="light"] .hljs { background: var(--code-bg); }
          [data-theme="dark"] .hljs { background: var(--code-bg); }
          .mermaid { text-align: center; margin-bottom: 16px; }
          .mermaid svg { max-width: 100%; height: auto; }
          .katex-display { margin: 16px 0; overflow-x: auto; }
        </style>
        <!-- KaTeX -->
        <style>\(ResourceLoader.katexCSS)</style>
        """
    }

    private static func richFeatureScripts(mermaid mermaidEnabled: Bool) -> String {
        let mermaidScript = mermaidEnabled ? "<script>\(ResourceLoader.mermaidJS)</script>" : ""
        let mermaidInit = mermaidEnabled ? """
              // Mermaid diagrams — detect theme
              if (typeof mermaid !== 'undefined') {
                var dt = document.documentElement.getAttribute('data-theme');
                var isDark = dt === 'dark' || (dt === 'auto' && window.matchMedia('(prefers-color-scheme: dark)').matches);
                mermaid.initialize({ startOnLoad: true, securityLevel: 'strict', theme: isDark ? 'dark' : 'default' });
              }
        """ : ""
        return """
        <script>\(ResourceLoader.highlightJS)</script>
        <script>\(ResourceLoader.katexJS)</script>
        <script>\(ResourceLoader.autoRenderJS)</script>
        \(mermaidScript)
        <script>
        document.addEventListener('DOMContentLoaded', function() {
          // Syntax highlighting — only code blocks with a specified language
          document.querySelectorAll('pre code[class*="language-"]').forEach(function(el) {
            if (typeof hljs !== 'undefined') hljs.highlightElement(el);
          });
          // KaTeX auto-render for $...$ and $$...$$ math expressions
          if (typeof renderMathInElement !== 'undefined') {
            renderMathInElement(document.body, {
              delimiters: [
                {left: '$$', right: '$$', display: true},
                {left: '$', right: '$', display: false}
              ],
              throwOnError: false,
              ignoredTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code']
            });
          }
        \(mermaidInit)
        });
        </script>
        """
    }

    private static let css = """
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
        a[href^="#"] { pointer-events: auto; cursor: pointer; }
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
        li input[type="checkbox"] { margin-right: 6px; vertical-align: middle; }
        li.task-list-item { list-style: none; margin-left: -20px; }
        li.task-list-item > p { display: inline; margin: 0; }
        li.task-list-item > p:first-of-type { display: inline; }
        li.task-list-item input[type="checkbox"] { margin-right: 8px; }
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
        details.frontmatter {
          border: 1px solid var(--border);
          border-radius: 6px;
          margin-bottom: 24px;
          overflow: hidden;
        }
        details.frontmatter summary {
          cursor: pointer;
          padding: 8px 12px;
          font-size: 0.8em;
          font-weight: 600;
          letter-spacing: 0.04em;
          text-transform: uppercase;
          color: var(--text);
          opacity: 0.5;
          background: var(--code-bg);
          user-select: none;
          list-style: none;
        }
        details.frontmatter summary::before {
          content: '▶';
          display: inline-block;
          margin-right: 6px;
          font-size: 0.7em;
          transition: transform 0.15s;
        }
        details.frontmatter[open] summary::before { transform: rotate(90deg); }
        details.frontmatter table {
          width: 100%;
          margin: 0;
          border-radius: 0;
          font-size: 0.85em;
        }
        details.frontmatter th { width: 30%; }
        mark {
          background: rgba(255, 230, 0, 0.35);
          padding: 1px 3px;
          border-radius: 2px;
        }
        [data-theme="dark"] mark { background: rgba(255, 230, 0, 0.2); }
        @media (prefers-color-scheme: dark) {
          :root mark { background: rgba(255, 230, 0, 0.2); }
        }
        sup.footnote-ref a {
          text-decoration: none;
          color: var(--link);
          font-weight: 600;
        }
        .footnotes-sep { margin-top: 32px; }
        .footnotes { font-size: 0.85em; opacity: 0.85; }
        .footnotes ol { padding-left: 20px; }
        .footnote-backref { text-decoration: none; margin-left: 4px; }

        /* GitHub-style alerts */
        .markdown-alert {
          border-left: 4px solid;
          border-radius: 6px;
          padding: 12px 16px;
          margin-bottom: 16px;
          background: var(--code-bg);
        }
        .markdown-alert > :last-child { margin-bottom: 0; }
        .markdown-alert-title {
          font-weight: 600;
          font-size: 0.9em;
          margin-bottom: 4px;
        }
        .markdown-alert-note { border-left-color: #1f6feb; }
        .markdown-alert-note .markdown-alert-title { color: #4493f8; }
        .markdown-alert-tip { border-left-color: #238636; }
        .markdown-alert-tip .markdown-alert-title { color: #3fb950; }
        .markdown-alert-important { border-left-color: #8957e5; }
        .markdown-alert-important .markdown-alert-title { color: #ab7df8; }
        .markdown-alert-warning { border-left-color: #d29922; }
        .markdown-alert-warning .markdown-alert-title { color: #d29922; }
        .markdown-alert-caution { border-left-color: #da3633; }
        .markdown-alert-caution .markdown-alert-title { color: #f85149; }

        /* Agentic AI XML-like tags — render as visible labeled blocks */
        example, instructions, rule, context, important,
        example-agent, system-prompt, user-prompt, assistant-response,
        tool-use, tool-result, thinking, reflection, planning,
        constraints, guidelines, persona, task, step, output-format {
          display: block;
          border: 1px solid var(--border);
          border-radius: 6px;
          padding: 12px 16px;
          margin: 12px 0;
          position: relative;
          padding-top: 28px;
        }
        example::before { content: "<example>"; }
        instructions::before { content: "<instructions>"; }
        rule::before { content: "<rule>"; }
        context::before { content: "<context>"; }
        important::before { content: "<important>"; }
        example-agent::before { content: "<example-agent>"; }
        system-prompt::before { content: "<system-prompt>"; }
        user-prompt::before { content: "<user-prompt>"; }
        assistant-response::before { content: "<assistant-response>"; }
        tool-use::before { content: "<tool-use>"; }
        tool-result::before { content: "<tool-result>"; }
        thinking::before { content: "<thinking>"; }
        reflection::before { content: "<reflection>"; }
        planning::before { content: "<planning>"; }
        constraints::before { content: "<constraints>"; }
        guidelines::before { content: "<guidelines>"; }
        persona::before { content: "<persona>"; }
        task::before { content: "<task>"; }
        step::before { content: "<step>"; }
        output-format::before { content: "<output-format>"; }
        example::before, instructions::before, rule::before,
        context::before, important::before, example-agent::before,
        system-prompt::before, user-prompt::before, assistant-response::before,
        tool-use::before, tool-result::before, thinking::before,
        reflection::before, planning::before, constraints::before,
        guidelines::before, persona::before, task::before,
        step::before, output-format::before {
          position: absolute;
          top: 4px;
          left: 8px;
          font-size: 0.7em;
          font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
          opacity: 0.45;
          letter-spacing: 0.02em;
        }
        important { border-color: #d29922; background: rgba(210, 153, 34, 0.06); }
        example { border-color: #238636; background: rgba(35, 134, 54, 0.06); }
        thinking, reflection, planning { border-style: dashed; opacity: 0.8; }
        """
}
