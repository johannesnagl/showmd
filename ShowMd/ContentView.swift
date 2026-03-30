import SwiftUI
import struct MarkdownRenderer.Settings

private typealias MdSettings = Settings

private let extensionBundleID = "io.github.showmd.app.extension"

private func isExtensionEnabled() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
    process.arguments = ["-m", "-p", "com.apple.quicklook.preview", "-i", extensionBundleID]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    try? process.run()
    process.waitUntilExit()
    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    // pluginkit prefixes enabled extensions with "+" and disabled with "-"
    return output.contains("+")
}

struct ContentView: View {
    @State private var defaultTab: MdSettings.Tab = MdSettings.defaultTab
    @State private var theme: MdSettings.Theme = MdSettings.theme
    @State private var fontSize: MdSettings.FontSize = MdSettings.fontSize
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
        .preferredColorScheme(theme == .light ? .light : theme == .dark ? .dark : nil)
        .onAppear { extensionEnabled = isExtensionEnabled() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            extensionEnabled = isExtensionEnabled()
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
                HStack {
                    Label {
                        Text("Quick Look Extension")
                    } icon: {
                        Image(systemName: extensionEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(extensionEnabled ? .green : .red)
                    }
                    Spacer()
                    Button(extensionEnabled ? "Manage in Settings" : "Enable Extension") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.link)
                }

                Picker("Default Tab", selection: $defaultTab) {
                    Text("Rendered").tag(MdSettings.Tab.rendered)
                    Text("Source").tag(MdSettings.Tab.source)
                }
                .pickerStyle(.segmented)
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
