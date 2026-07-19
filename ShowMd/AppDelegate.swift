import AppKit
import struct MarkdownRenderer.Settings

// No `MdSettings` typealias here, unlike the SwiftUI files: this file doesn't
// import SwiftUI, so there's no clash with `SwiftUI.Settings`. A private alias
// would also leak into `AppPresentation`'s signature, which ContentView calls.

/// Translates the stored presentation preference into an AppKit activation policy.
///
/// `.regular` shows the Dock icon; `.accessory` hides it and leaves the menu bar
/// item as the only affordance. `Settings.Presentation` guarantees exactly one of
/// the two is active, so showmd can never become unreachable.
enum AppPresentation {
    static func policy(for presentation: Settings.Presentation) -> NSApplication.ActivationPolicy {
        presentation.showsDockIcon ? .regular : .accessory
    }

    static func apply(_ presentation: Settings.Presentation) {
        let policy = policy(for: presentation)
        guard NSApp.activationPolicy() != policy else { return }

        NSApp.setActivationPolicy(policy)

        // Coming back from .accessory, AppKit needs an explicit activation to
        // restore the main menu and bring the settings window forward.
        if policy == .regular {
            NSApp.activate()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Applied before launch finishes so the Dock icon never flashes on screen
    /// when starting in menu bar mode.
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppPresentation.apply(Settings.presentation)
    }

    /// In menu bar mode the window is not the only way back into showmd, so
    /// closing it leaves the app running. Dock mode keeps the previous behavior.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !Settings.menuBarMode
    }
}
