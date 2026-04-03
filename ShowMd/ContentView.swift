import SwiftUI
import struct MarkdownRenderer.Settings

private typealias MdSettings = Settings

private let extensionBundleID = "io.github.showmd.app.extension"

private func checkExtensionEnabled(completion: @escaping (Bool) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        // Try pluginkit first (works when not sandboxed)
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
            let enabled = output.contains(extensionBundleID)
            DispatchQueue.main.async { completion(enabled) }
        } catch {
            // If Process fails (e.g. under sandbox), fall back to checking
            // if the extension bundle exists inside the app bundle
            let extensionURL = Bundle.main.builtInPlugInsURL?
                .appendingPathComponent("ShowMdExtension.appex")
            let exists = extensionURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            DispatchQueue.main.async { completion(exists) }
        }
    }
}

struct ContentView: View {
    @State private var defaultTab: MdSettings.Tab = MdSettings.defaultTab
    @State private var theme: MdSettings.Theme = MdSettings.theme
    @State private var fontSize: MdSettings.FontSize = MdSettings.fontSize
    @State private var mermaidEnabled: Bool = MdSettings.mermaidEnabled
    @State private var extensionEnabled: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            headerView
            formView
            footerView
        }
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
                if extensionEnabled {
                    HStack {
                        Label("Extension active", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Manage in System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }
                } else {
                    HStack {
                        Label("Extension not installed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Enable in System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }
                }

                Picker("Default Tab", selection: $defaultTab) {
                    Text("Rendered").tag(MdSettings.Tab.rendered)
                    Text("Source").tag(MdSettings.Tab.source)
                }
                .pickerStyle(.segmented)
            }

            Section("Rich Content") {
                Toggle("Mermaid Diagrams", isOn: $mermaidEnabled)
                Text("Render Mermaid diagram code blocks as visual charts. Increases preview load time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
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
            }
        }
        .formStyle(.grouped)
    }

    private var footerView: some View {
        HStack(spacing: 16) {
            Button("Buy me a pasta ☕") {
                if let url = URL(string: "https://buymeacoffee.com/johannesnagl") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)

            Button("GitHub") {
                if let url = URL(string: "https://github.com/johannesnagl/show.md") {
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
