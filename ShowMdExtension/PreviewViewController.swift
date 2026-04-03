import Cocoa
import Quartz
import WebKit
import MarkdownRenderer

class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {
    private var webView: WKWebView?
    private var segmentedControl: NSSegmentedControl!
    private var copyButton: NSButton!
    private var markdownSource = ""
    private var renderedHTML = ""
    private var fileDirectoryURL: URL?
    private var currentTab: Settings.Tab = Settings.defaultTab

    private var lastTheme: Settings.Theme = Settings.theme
    private var lastFontSize: Settings.FontSize = Settings.fontSize
    private var lastMermaid: Bool = Settings.mermaidEnabled

    private static let imgSrcPattern = try! NSRegularExpression(
        pattern: #"(<img\s[^>]*?\bsrc\s*=\s*")((?!data:|https?://)[^"]+)(")"#,
        options: .caseInsensitive
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: UserDefaults.didChangeNotification,
            object: Settings.userDefaults
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func settingsChanged() {
        guard !markdownSource.isEmpty else { return }
        let newTheme = Settings.theme
        let newFontSize = Settings.fontSize
        let newMermaid = Settings.mermaidEnabled
        guard newTheme != lastTheme || newFontSize != lastFontSize || newMermaid != lastMermaid else { return }
        lastTheme = newTheme
        lastFontSize = newFontSize
        lastMermaid = newMermaid
        loadCombined()
    }

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

        copyButton = NSButton(title: "Copy as HTML", target: self, action: #selector(copyAsHTML))
        copyButton.bezelStyle = .rounded
        copyButton.controlSize = .small
        copyButton.translatesAutoresizingMaskIntoConstraints = false

        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.navigationDelegate = self
        webView = wv

        view.addSubview(segmentedControl)
        view.addSubview(copyButton)
        view.addSubview(wv)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            segmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            copyButton.centerYAnchor.constraint(equalTo: segmentedControl.centerYAnchor),
            copyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            wv.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            wv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        // No [weak self] — these are one-shot dispatch blocks, not stored closures.
        // The view controller MUST stay alive until content is loaded; using weak self
        // here caused blank previews because QL can release the controller before the
        // main-queue callback runs (the view stays in the window, but self is nil).
        DispatchQueue.global(qos: .userInitiated).async {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let source = try String(contentsOf: url, encoding: .utf8)
                DispatchQueue.main.async {
                    self.currentTab = Settings.defaultTab
                    self.segmentedControl?.selectedSegment = self.currentTab == .rendered ? 0 : 1
                    self.copyButton?.isHidden = self.currentTab != .rendered
                    self.markdownSource = source
                    self.fileDirectoryURL = url.deletingLastPathComponent()
                    self.loadCombined()
                    handler(nil)
                }
            } catch {
                DispatchQueue.main.async { handler(error) }
            }
        }
    }

    @objc private func tabChanged(_ sender: NSSegmentedControl) {
        currentTab = sender.selectedSegment == 0 ? .rendered : .source
        let cls = currentTab == .rendered ? "tab-rendered" : "tab-source"
        webView?.evaluateJavaScript("document.documentElement.className = '\(cls)'", completionHandler: nil)
        copyButton.isHidden = currentTab != .rendered
    }

    @objc private func copyAsHTML() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(renderedHTML, forType: .string)
        copyButton.title = "Copied!"
        copyButton.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.copyButton.title = "Copy as HTML"
            self?.copyButton.isEnabled = true
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog("[showmd] WKWebView didFinish navigation")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("[showmd] WKWebView didFail: %@", error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("[showmd] WKWebView didFailProvisionalNavigation: %@", error.localizedDescription)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        NSLog("[showmd] WebContent process TERMINATED — HTML too large or JS crash")
        let html = MarkdownRenderer.renderCombined(
            markdownSource,
            theme: Settings.theme,
            fontSize: Settings.fontSize,
            defaultTab: currentTab,
            mermaid: false
        )
        webView.loadHTMLString(html, baseURL: fileDirectoryURL)
    }

    // MARK: - Image inlining

    /// Replace relative image src attributes with base64 data URIs so they render
    /// inside the sandboxed WKWebView (which cannot load local file:// resources).
    private func inlineLocalImages(in html: String, baseDirectory: URL) -> String {
        let mutable = NSMutableString(string: html)
        let fullRange = NSRange(location: 0, length: mutable.length)
        let matches = Self.imgSrcPattern.matches(in: html, range: fullRange).reversed()

        for match in matches {
            guard let srcRange = Range(match.range(at: 2), in: html) else { continue }
            let relativePath = String(html[srcRange])

            let fileURL = baseDirectory.appendingPathComponent(relativePath)
            guard FileManager.default.fileExists(atPath: fileURL.path),
                  let data = try? Data(contentsOf: fileURL) else { continue }

            let mime = Self.mimeType(for: fileURL.pathExtension)
            let dataURI = "data:\(mime);base64,\(data.base64EncodedString())"

            mutable.replaceCharacters(in: match.range(at: 2), with: dataURI)
        }
        return mutable as String
    }

    private static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "avif": return "image/avif"
        case "ico": return "image/x-icon"
        case "bmp": return "image/bmp"
        default: return "application/octet-stream"
        }
    }

    // MARK: - Rendering

    private func loadCombined() {
        guard let webView else { return }
        renderedHTML = MarkdownRenderer.renderBody(markdownSource)
        var html = MarkdownRenderer.renderCombined(
            markdownSource,
            theme: Settings.theme,
            fontSize: Settings.fontSize,
            defaultTab: currentTab,
            mermaid: Settings.mermaidEnabled
        )
        if let baseDir = fileDirectoryURL {
            html = inlineLocalImages(in: html, baseDirectory: baseDir)
        }
        webView.loadHTMLString(html, baseURL: fileDirectoryURL)
    }
}
