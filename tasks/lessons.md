# Lessons Learned — show.md

## Project

Native macOS Quick Look Preview Extension for Markdown files. Swift package (`MarkdownRenderer`) shared between the QL extension and host app via App Groups.

---

## Swift Package

### swift-tools-version and swift-testing

At `swift-tools-version: 5.9`, the `Testing` module is NOT automatically linked — you need the explicit SPM dependency:

```swift
.package(url: "https://github.com/apple/swift-testing.git", from: "0.7.0")
```

At `swift-tools-version: 6.0`, swift-testing is bundled and the explicit dep is unnecessary. But 6.0 also enables strict concurrency, which cascades `@MainActor` requirements you don't want on simple `UserDefaults` accessors.

**Decision: stay at 5.9, keep explicit swift-testing dep.**

### Settings namespace clash

`SwiftUI` defines its own `Settings` scene type. Bare `import MarkdownRenderer` in a SwiftUI file causes an ambiguous `Settings` reference.

**Fix:**
```swift
import struct MarkdownRenderer.Settings
private typealias MdSettings = Settings
```

### @MainActor on UserDefaults-backed properties

`UserDefaults` is thread-safe. Adding `@MainActor` to Settings static properties is unnecessary and restricts all call sites (Quick Look extension, rendering pipeline) to the main actor. Don't do it.

### App Groups suite name

Suite name used throughout: `group.io.github.show-md`
Must be identical in:
- `Settings.swift` (`UserDefaults(suiteName:)`)
- `ShowMd/ShowMd.entitlements`
- `ShowMdExtension/ShowMdExtension.entitlements`
- Xcode Signing & Capabilities for both targets

---

## macOS Version

Apple switched to year-based numbering. Latest macOS (as of 2026) is **macOS 26**, not 15.

At `swift-tools-version: 5.9`, `.macOS(.v15)` enum case is unavailable — use the string form `.macOS("26.0")` instead.

---

## XcodeGen

Use `CODE_SIGN_ENTITLEMENTS` as a build setting to reference entitlement files — do NOT use XcodeGen's top-level `entitlements: path:` key, which overwrites the entitlement file content on generation.

`DEVELOPMENT_TEAM` is intentionally omitted from `project.yml`. Set it per-machine in Xcode → Signing & Capabilities.

The generated `.xcodeproj` is excluded from git (generated from `project.yml` via `xcodegen generate`).

---

## Quick Look Extension

### QLPreviewingController file read

`preparePreviewOfFile(at:completionHandler:)` is called on the main thread. Always dispatch file I/O to a background queue:

```swift
DispatchQueue.global(qos: .userInitiated).async {
    let source = try String(contentsOf: url, encoding: .utf8)
    DispatchQueue.main.async {
        // update UI, call handler
    }
}
```

### WKWebView as optional

Declare `webView` as `WKWebView?` (not `WKWebView!`) and guard at the top of any method that uses it. `preparePreviewOfFile` can theoretically be called before `loadView` completes in certain hosting configurations.

---

## SwiftUI (macOS 26)

### onChange signature

The single-argument closure form is deprecated on macOS 14+. Use the two-argument form:

```swift
// Wrong (deprecated)
.onChange(of: value) { Settings.x = $0 }

// Correct
.onChange(of: value) { _, newValue in Settings.x = newValue }
```

### formStyle(.grouped) for settings windows

`Form { }.formStyle(.grouped)` is the macOS-native pattern for settings panels — no custom card styling needed.

---

## Git Hygiene

- `MarkdownRenderer/Package.resolved` should NOT be committed for a library package. Add to `.gitignore` AND run `git rm --cached` to untrack it if already committed.
- One commit per task. Review-loop fixes go into the same commit via `git commit --amend --no-edit`.
- Empty scaffold directories must have `.gitkeep` files — git does not track empty directories.
- To squash multiple commits into one: `GIT_SEQUENCE_EDITOR="perl -i -pe 's/^pick /fixup / if \$. >= 2 && \$. <= N'" git rebase -i --root` (remove any untracked files that could block the rebase first).

---

## Release Checklist (when ready)

1. Set DEVELOPMENT_TEAM in Xcode for both targets
2. Archive → Distribute → Developer ID
3. `xcrun notarytool submit ... --wait`
4. `xcrun stapler staple show.md.app`
5. `ditto -c -k --sequesterRsrc --keepParent show.md.app show.md-VERSION.zip`
6. `shasum -a 256 show.md-VERSION.zip` → use in Homebrew cask
7. `git tag vVERSION && git push origin main --tags`
8. Create GitHub release, upload zip + sha256
9. Update `Casks/show-md.rb` in homebrew-tap repo
