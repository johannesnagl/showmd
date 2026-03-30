import SwiftUI
import struct MarkdownRenderer.Settings

private typealias MdSettings = Settings

struct ContentView: View {
    @State private var defaultTab: MdSettings.Tab = MdSettings.defaultTab
    @State private var theme: MdSettings.Theme = MdSettings.theme
    @State private var fontSize: MdSettings.FontSize = MdSettings.fontSize

    var body: some View {
        VStack(spacing: 0) {
            headerView
            formView
            footerView
        }
        .onChange(of: defaultTab) { _, newValue in MdSettings.defaultTab = newValue }
        .onChange(of: theme)      { _, newValue in MdSettings.theme = newValue }
        .onChange(of: fontSize)   { _, newValue in MdSettings.fontSize = newValue }
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
                    Text("Quick Look Extension")
                    Spacer()
                    Button("Open in System Settings") {
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
