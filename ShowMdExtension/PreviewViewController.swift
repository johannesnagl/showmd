import Cocoa
import Quartz
import WebKit
import MarkdownRenderer

class PreviewViewController: NSViewController, QLPreviewingController {
    private var webView: WKWebView?
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
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.translatesAutoresizingMaskIntoConstraints = false
        webView = wv

        view.addSubview(segmentedControl)
        view.addSubview(wv)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            segmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),

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
    }

    private func loadCombined() {
        guard let webView else { return }
        let html = MarkdownRenderer.renderCombined(
            markdownSource,
            theme: Settings.theme,
            fontSize: Settings.fontSize,
            defaultTab: currentTab
        )
        webView.loadHTMLString(html, baseURL: nil)
    }
}
