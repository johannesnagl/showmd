import AppKit

/// System Settings deep links, shared by the settings window and the menu bar menu.
enum SystemSettings {
    /// Opens System Settings → Privacy & Security → Extensions → Quick Look.
    static func openQuickLookExtensions() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") else { return }
        NSWorkspace.shared.open(url)
    }
}
