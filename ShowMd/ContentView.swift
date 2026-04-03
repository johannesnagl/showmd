import SwiftUI
import struct MarkdownRenderer.Settings

private typealias MdSettings = Settings

private let extensionBundleID = "io.github.showmd.app.extension"

private func checkExtensionEnabled(completion: @escaping (Bool) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = ["-m", "-p", "com.apple.quicklook.preview", "-i", extensionBundleID]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            // pluginkit prefixes: "+" = enabled, "-" = disabled, " " = default.
            // With EXDefaultUserElection=1 in Info.plist, default (" ") means enabled.
            let disabled = output.contains(extensionBundleID) &&
                output.split(separator: "\n")
                    .first { $0.contains(extensionBundleID) }
                    .map { $0.hasPrefix("-") } ?? false
            let enabled = output.contains(extensionBundleID) && !disabled
            DispatchQueue.main.async { completion(enabled) }
        } catch {
            let extensionURL = Bundle.main.builtInPlugInsURL?
                .appendingPathComponent("ShowMdExtension.appex")
            let exists = extensionURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            DispatchQueue.main.async { completion(exists) }
        }
    }
}

// MARK: - Logo

/// The showmd logo drawn natively in SwiftUI — document with magnifier.
private struct LogoView: View {
    var size: CGFloat = 64

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 64

            // Background
            let bgPath = RoundedRectangle(cornerRadius: 14 * s)
                .path(in: CGRect(origin: .zero, size: canvasSize))
            context.fill(bgPath,
                         with: .color(Color(nsColor: NSColor(red: 0.086, green: 0.086, blue: 0.086, alpha: 1))))

            // Document outline (open path)
            var doc = Path()
            doc.move(to: CGPoint(x: 29 * s, y: 52 * s))
            doc.addLine(to: CGPoint(x: 12 * s, y: 52 * s))
            doc.addQuadCurve(to: CGPoint(x: 9 * s, y: 49 * s),
                             control: CGPoint(x: 9 * s, y: 52 * s))
            doc.addLine(to: CGPoint(x: 9 * s, y: 8 * s))
            doc.addQuadCurve(to: CGPoint(x: 12 * s, y: 5 * s),
                             control: CGPoint(x: 9 * s, y: 5 * s))
            doc.addLine(to: CGPoint(x: 41 * s, y: 5 * s))
            doc.addQuadCurve(to: CGPoint(x: 44 * s, y: 8 * s),
                             control: CGPoint(x: 44 * s, y: 5 * s))
            doc.addLine(to: CGPoint(x: 44 * s, y: 36 * s))
            context.stroke(doc, with: .color(.white),
                           style: StrokeStyle(lineWidth: 1.5 * s, lineCap: .round, lineJoin: .round))

            // Content lines
            let lines: [(x1: CGFloat, x2: CGFloat, y: CGFloat, w: CGFloat, op: Double)] = [
                (14, 40, 16, 1.0, 0.6),
                (14, 34, 22, 0.8, 0.3),
                (14, 37, 27, 0.8, 0.3),
            ]
            for l in lines {
                var line = Path()
                line.move(to: CGPoint(x: l.x1 * s, y: l.y * s))
                line.addLine(to: CGPoint(x: l.x2 * s, y: l.y * s))
                context.stroke(line, with: .color(.white.opacity(l.op)),
                               style: StrokeStyle(lineWidth: l.w * s, lineCap: .round))
            }

            // Magnifier lens
            let lensCenter = CGPoint(x: 41 * s, y: 48 * s)
            let lensRadius = 12 * s
            let lensRect = CGRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius,
                                  width: lensRadius * 2, height: lensRadius * 2)
            context.fill(Path(ellipseIn: lensRect),
                         with: .color(Color(red: 0.243, green: 0.710, blue: 0.690).opacity(0.07)))
            context.stroke(Path(ellipseIn: lensRect), with: .color(.white),
                           style: StrokeStyle(lineWidth: 1.5 * s))

            // Handle
            var handle = Path()
            handle.move(to: CGPoint(x: 50 * s, y: 57 * s))
            handle.addLine(to: CGPoint(x: 56 * s, y: 62 * s))
            context.stroke(handle, with: .color(.white),
                           style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Content

struct ContentView: View {
    @State private var defaultTab: MdSettings.Tab = MdSettings.defaultTab
    @State private var theme: MdSettings.Theme = MdSettings.theme
    @State private var fontSize: MdSettings.FontSize = MdSettings.fontSize
    @State private var mermaidEnabled: Bool = MdSettings.mermaidEnabled
    @State private var extensionEnabled: Bool = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            formView
            Divider()
            footerView
        }
        .frame(width: 440)
        .onChange(of: defaultTab) { _, newValue in MdSettings.defaultTab = newValue }
        .onChange(of: theme)      { _, newValue in MdSettings.theme = newValue }
        .onChange(of: fontSize)   { _, newValue in MdSettings.fontSize = newValue }
        .onChange(of: mermaidEnabled) { _, newValue in MdSettings.mermaidEnabled = newValue }
        .preferredColorScheme(theme == .light ? .light : theme == .dark ? .dark : nil)
        .onAppear { checkExtensionEnabled { extensionEnabled = $0 } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkExtensionEnabled { extensionEnabled = $0 }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 14) {
            LogoView(size: 56)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("showmd")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("v\(version)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .baselineOffset(1)
                }
                Text("Quick Look preview for Markdown files")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    // MARK: - Settings form

    private var formView: some View {
        Form {
            Section {
                extensionStatusRow
                Picker("Default Tab", selection: $defaultTab) {
                    Text("Rendered").tag(MdSettings.Tab.rendered)
                    Text("Source").tag(MdSettings.Tab.source)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Preview")
            }

            Section {
                Toggle("Mermaid Diagrams", isOn: $mermaidEnabled)
                Text("Render Mermaid code blocks as visual charts. Increases preview load time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Rich Content")
            }

            Section {
                Picker("Theme", selection: $theme) {
                    Text("Auto").tag(MdSettings.Theme.auto)
                    Text("Light").tag(MdSettings.Theme.light)
                    Text("Dark").tag(MdSettings.Theme.dark)
                }
                .pickerStyle(.segmented)

                Picker("Font Size", selection: $fontSize) {
                    Text("Small").tag(MdSettings.FontSize.small)
                    Text("Medium").tag(MdSettings.FontSize.medium)
                    Text("Large").tag(MdSettings.FontSize.large)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
            }
        }
        .formStyle(.grouped)
    }

    private var extensionStatusRow: some View {
        HStack {
            if extensionEnabled {
                Label("Extension active", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Extension not enabled", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            Spacer()
            Button(extensionEnabled ? "Manage" : "Enable") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
            .font(.caption)
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 6) {
            Link(destination: URL(string: "https://github.com/johannesnagl/show.md")!) {
                Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Text("  ·  ")
                .foregroundStyle(.quaternary)
            Link(destination: URL(string: "https://mojo.tech/showmd")!) {
                Label("Website", systemImage: "globe")
            }
            Text("  ·  ")
                .foregroundStyle(.quaternary)
            Link(destination: URL(string: "https://buymeacoffee.com/johannesnagl")!) {
                Label("Buy me a pasta", systemImage: "cup.and.saucer")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 14)
    }
}
