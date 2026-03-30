import Cocoa
import Quartz
import WebKit
import MarkdownRenderer

class PreviewViewController: NSViewController, QLPreviewingController {
    private var webView: WKWebView?
    private var segmentedControl: NSSegmentedControl!
    private var copyButton: NSButton!
    private var markdownSource = ""
    private var renderedHTML = ""
    private var currentTab: Settings.Tab = Settings.defaultTab

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func settingsChanged() {
        guard !markdownSource.isEmpty else { return }
        let cls = currentTab == .rendered ? "tab-rendered" : "tab-source"
        loadCombined()
        webView?.evaluateJavaScript("document.documentElement.className = '\(cls)'")
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
        webView?.evaluateJavaScript("document.documentElement.className = '\(cls)'")
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

    private func loadCombined() {
        guard let webView else { return }
        renderedHTML = MarkdownRenderer.renderBody(markdownSource)
        let html = MarkdownRenderer.renderCombined(
            markdownSource,
            theme: Settings.theme,
            fontSize: Settings.fontSize,
            defaultTab: currentTab
        )
        webView.loadHTMLString(html, baseURL: nil)
    }
}
