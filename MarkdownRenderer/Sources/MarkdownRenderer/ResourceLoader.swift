import Foundation

enum ResourceLoader {
    static func load(_ filename: String) -> String {
        guard let url = Bundle.module.url(forResource: filename, withExtension: nil, subdirectory: "Resources"),
              let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return ""
        }
        return content
    }

    // Cached resource contents — loaded once, reused across renders.
    static let highlightJS = load("highlight.min.js")
    static let highlightLightCSS = load("github.min.css")
    static let highlightDarkCSS = load("github-dark.min.css")
    static let katexJS = load("katex.min.js")
    static let katexCSS = load("katex.min.css")
    static let autoRenderJS = load("auto-render.min.js")
    static let mermaidJS = load("mermaid.min.js")
}
