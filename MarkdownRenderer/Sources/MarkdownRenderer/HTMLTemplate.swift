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
