import Testing
import Foundation
@testable import MarkdownRenderer

private let testSuiteName = "test.settings"

@Suite(.serialized) struct SettingsTests {
    init() {
        Settings.userDefaults = UserDefaults(suiteName: testSuiteName)!
        Settings.userDefaults.removePersistentDomain(forName: testSuiteName)
    }

    @Test func defaultTabDefaultsToRendered() {
        #expect(Settings.defaultTab == .rendered)
    }

    @Test func defaultTabRoundTrips() {
        Settings.defaultTab = .source
        #expect(Settings.defaultTab == .source)
    }

    @Test func themeDefaultsToAuto() {
        #expect(Settings.theme == .auto)
    }

    @Test func themeRoundTrips() {
        Settings.theme = .dark
        #expect(Settings.theme == .dark)
    }

    @Test func fontSizeDefaultsToMedium() {
        #expect(Settings.fontSize == .medium)
    }

    @Test func fontSizeRoundTrips() {
        Settings.fontSize = .large
        #expect(Settings.fontSize == .large)
    }

    @Test func fontSizeCSSValues() {
        #expect(Settings.FontSize.small.cssValue == "13px")
        #expect(Settings.FontSize.medium.cssValue == "15px")
        #expect(Settings.FontSize.large.cssValue == "17px")
    }

    @Test func unknownRawValueFallsBackToDefault() {
        Settings.userDefaults.set("garbage", forKey: "defaultTab")
        #expect(Settings.defaultTab == .rendered)
    }

    @Test func mermaidDefaultsToFalse() {
        #expect(Settings.mermaidEnabled == false)
    }

    @Test func mermaidRoundTrips() {
        Settings.mermaidEnabled = true
        #expect(Settings.mermaidEnabled == true)
    }

    // MARK: - Menu bar mode

    @Test func menuBarModeDefaultsToFalse() {
        #expect(Settings.menuBarMode == false)
    }

    @Test func menuBarModeRoundTrips() {
        Settings.menuBarMode = true
        #expect(Settings.menuBarMode == true)
    }

    @Test func menuBarModeFallsBackToFalseForNonBooleanValue() {
        Settings.userDefaults.set("garbage", forKey: "menuBarMode")
        #expect(Settings.menuBarMode == false)
    }

    @Test func presentationDefaultsToDock() {
        #expect(Settings.presentation == .dock)
    }

    @Test func presentationFollowsMenuBarMode() {
        Settings.menuBarMode = true
        #expect(Settings.presentation == .menuBar)
        Settings.menuBarMode = false
        #expect(Settings.presentation == .dock)
    }

    @Test func dockPresentationShowsOnlyTheDockIcon() {
        #expect(Settings.Presentation.dock.showsDockIcon)
        #expect(Settings.Presentation.dock.showsMenuBarItem == false)
    }

    @Test func menuBarPresentationShowsOnlyTheMenuBarItem() {
        #expect(Settings.Presentation.menuBar.showsMenuBarItem)
        #expect(Settings.Presentation.menuBar.showsDockIcon == false)
    }

    /// The app must never end up with zero affordances — that would leave it
    /// running with no way to reach or quit it.
    @Test func everyPresentationHasExactlyOneAffordance() {
        for presentation in Settings.Presentation.allCases {
            #expect(presentation.showsDockIcon != presentation.showsMenuBarItem)
        }
    }
}
