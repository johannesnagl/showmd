# Menu Bar Mode — Design

**Date:** 2026-07-19
**Status:** Approved

## Problem

showmd's host app is a settings panel for the Quick Look extension. Users open it
once to configure theme, font size, and Mermaid, then rarely again — but it keeps a
permanent Dock icon. Users who want showmd out of the Dock currently have no option.

## Goal

Add a preference that hides the Dock icon and puts showmd in the menu bar instead.

## Non-goals

- Showing in both the Dock and the menu bar simultaneously.
- Changing Quick Look preview behavior. Previews are handled by the extension and
  are unaffected by this preference.
- A menu bar popover UI. The menu bar item opens the existing settings window.

## Model

A single preference with two states, not two independent toggles:

| `menuBarMode` | Dock icon | Menu bar item |
|---------------|-----------|---------------|
| `false` (default) | shown | hidden |
| `true` | hidden | shown |

One toggle makes the invalid state — neither affordance present, leaving the app
unreachable — unrepresentable. The `Presentation` enum below encodes this so the
invariant is testable rather than merely intended.

## Architecture

The split follows what CI can verify. `.github/workflows/test.yml` runs only
`cd MarkdownRenderer && swift test`; the `ShowMd` app target is never compiled in
CI. So decision logic lives in the package where tests reach it, and AppKit is a
thin adapter over that decision.

### Package layer — `MarkdownRenderer/Sources/MarkdownRenderer/Settings.swift`

```swift
public enum Presentation: CaseIterable {
    case dock, menuBar
    public var showsDockIcon: Bool     { self == .dock }
    public var showsMenuBarItem: Bool  { self == .menuBar }
}

public static var menuBarMode: Bool      // stored, App Group UserDefaults, default false
public static var presentation: Presentation  // derived: menuBarMode ? .menuBar : .dock
```

`Bool` storage matches the existing `mermaidEnabled` pattern; `theme`/`fontSize`/
`defaultTab` use enums because they have three states each.

`Presentation` imports nothing beyond Foundation. This is deliberate — CI builds
this package on a `macos-15` runner, and the package is also linked into the
sandboxed Quick Look extension, which has no business importing AppKit.

Per `tasks/lessons.md`, no `@MainActor` on these properties: `UserDefaults` is
thread-safe and annotating it would constrain every call site.

### App layer — `ShowMd/`

**`AppDelegate.swift`** (new)

- `AppPresentation.policy(for:)` — maps `Presentation.showsDockIcon` to
  `.regular` / `.accessory`. Pure function, kept separate from the side effect.
- `AppPresentation.apply(_:)` — sets the policy, no-op if unchanged. On the
  `.accessory → .regular` transition it calls `NSApp.activate()`, which AppKit
  needs to restore the main menu and bring the window forward.
- `applicationWillFinishLaunching` — applies the policy early enough that the Dock
  icon never flashes when launching in menu bar mode.
- `applicationShouldTerminateAfterLastWindowClosed` — returns `!menuBarMode`. In
  menu bar mode the window is not the only affordance, so closing it leaves showmd
  running; Dock mode keeps today's quit-on-close behavior exactly.

**`ShowMdApp.swift`**

- `WindowGroup("showmd")` → `Window("showmd", id: "main")`. Required so
  `openWindow(id:)` from the menu focuses the existing settings window instead of
  spawning a duplicate every time. `Window` is also the correct primitive for a
  single settings panel — this is a simplification, not added machinery.
- `MenuBarExtra(..., systemImage: "doc.text.magnifyingglass", isInserted:)` bound
  to `@AppStorage("menuBarMode", store: Settings.userDefaults)`, so the item
  appears and disappears live without a relaunch. The `systemImage:` initializer
  renders as a template image, so it adapts to light and dark menu bars.
- Menu contents: *Open showmd* · *Quick Look Extension Settings…* · separator ·
  *Quit showmd*. Quit matters — with no Dock icon there is otherwise no obvious
  way to quit.

**`SystemSettings.swift`** (new, small)

Extracts the `x-apple.systempreferences:com.apple.ExtensionsPreferences` URL,
which is now needed by both `ContentView.extensionStatusRow` and the menu bar
menu. Removes duplication this change would otherwise introduce.

**`ContentView.swift`**

New `General` section at the end of the form with the toggle and a caption,
following the file's existing `@State` + `.onChange` → `MdSettings.x` pattern.
Uses the `MdSettings` typealias already established in the file, per the
`SwiftUI.Settings` name-clash lesson in `tasks/lessons.md`.

`Info.plist` is untouched. `LSUIElement` would hard-code accessory mode; the
policy is applied at runtime instead so the preference can be toggled live.

## Data flow

```
ContentView toggle
  → Settings.menuBarMode (App Group UserDefaults)
      ├→ AppPresentation.apply()  → NSApp.setActivationPolicy()   [Dock icon]
      └→ @AppStorage KVO          → MenuBarExtra isInserted        [menu bar item]
```

Both observers read the same key, so the two affordances cannot drift apart.

## Testing

Eight tests added to `SettingsTests.swift`:

- `menuBarMode` — defaults to false, round-trips, falls back to false on a
  non-boolean stored value (mirrors the existing `unknownRawValueFallsBackToDefault`)
- `presentation` — defaults to `.dock`, tracks `menuBarMode` in both directions
- `Presentation` — `.dock` exposes only the Dock icon, `.menuBar` only the menu bar
  item, and across `allCases` exactly one affordance is always active

**XSS tests: not applicable.** This adds no rendering path and puts no
user-supplied content into HTML. `CONTRIBUTING.md` rule 5 governs `MarkdownRenderer`
HTML output; this change touches only `UserDefaults` and AppKit state.

**Entitlements: untouched.** `CONTRIBUTING.md` rule 6 and the
`com.apple.security.network.client` incident in `tasks/lessons.md` are not in play.

The `ShowMd` app target is unreachable from `swift test` — the same limitation
`tasks/lessons.md` already records for WKWebView rendering. Covered by building and
manually exercising the app: toggle both directions, confirm the Dock icon and menu
bar item swap, each menu item works, closing the window in menu bar mode leaves the
app running, and the setting survives a relaunch.

## Risks

| Risk | Mitigation |
|------|-----------|
| App unreachable with no Dock icon and no menu bar item | `Presentation` makes the state unrepresentable; covered by the exactly-one-affordance test |
| No way to quit without a Dock icon | Explicit *Quit showmd* menu item |
| Dock icon flashes at launch in menu bar mode | Policy applied in `applicationWillFinishLaunching`, before the icon is drawn |
| Menu bar returns empty after `.accessory → .regular` | `AppPresentation.apply` re-activates on that transition |
| App quits when the window closes in menu bar mode | `applicationShouldTerminateAfterLastWindowClosed` returns false in that mode |
