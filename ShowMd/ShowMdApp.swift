import SwiftUI
import struct MarkdownRenderer.Settings

private typealias MdSettings = Settings

private let mainWindowID = "main"

@main
struct ShowMdApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Bound to `MenuBarExtra`'s `isInserted`, so the item appears and disappears
    /// as soon as the preference changes — no relaunch needed.
    @AppStorage("menuBarMode", store: MdSettings.userDefaults)
    private var menuBarMode = false

    var body: some Scene {
        // A single `Window` rather than a `WindowGroup`: "Open showmd" should
        // focus the existing settings window, not open a second copy of it.
        Window("showmd", id: mainWindowID) {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 460, height: 480)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra("showmd", systemImage: "doc.text.magnifyingglass", isInserted: $menuBarMode) {
            MenuBarMenu()
        }
    }
}

/// Contents of the menu bar dropdown, kept as a view so it can read `openWindow`
/// from the environment.
private struct MenuBarMenu: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open showmd") {
            NSApp.activate()
            openWindow(id: mainWindowID)
        }

        Button("Quick Look Extension Settings…") {
            SystemSettings.openQuickLookExtensions()
        }

        Divider()

        // With the Dock icon hidden, this is the only way to quit.
        Button("Quit showmd") {
            NSApp.terminate(nil)
        }
    }
}
