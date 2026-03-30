# show.md — Design Document

A native macOS Quick Look Preview Extension that renders Markdown files beautifully instead of showing plain text. Distributed as a signed/notarized `.app` on GitHub Releases + Homebrew Cask.

---

## Decisions

| Topic | Decision |
|---|---|
| Type | Quick Look Preview Extension + host app with settings UI |
| Markdown spec | Full GFM (tables, task lists, strikethrough, autolinks) |
| Rendering | Swift + WKWebView |
| Parser | `apple/swift-markdown` (SPM) |
| Theming | System-adaptive by default, user-overridable to Light or Dark |
| Source view | Plain monospace, no syntax highlighting |
| Default tab | User-configurable, defaults to "Rendered" |
| Distribution | GitHub Releases (signed + notarized) + Homebrew Cask |

---

## Section 1: Project Structure

**Xcode project with two targets:**

1. **show.md** (host app) — SwiftUI macOS app with settings window. `LSUIElement = NO` (appears in Dock). No document handling.
2. **show.md Quick Look Extension** — Quick Look Preview Extension handling `.md`, `.markdown`, `.mdown`, `.mkd`, `.mkdn`, `.mdtext`, `.mdtxt`.

**Shared code:** Local Swift package (`MarkdownRenderer`) containing:
- Markdown-to-HTML rendering pipeline (`swift-markdown` parsing + HTML generation + CSS)
- Settings accessor via App Groups (`group.com.yourteam.show-md`) using `UserDefaults(suiteName:)`

**Dependencies:**
- `apple/swift-markdown` (SPM) — only external dependency

---

## Section 2: Quick Look Extension

**Extension type:** Modern `QLPreviewingController` protocol (not the deprecated generator API).

**Rendering pipeline:**
1. File passed as `URL` to the extension
2. Read file contents as UTF-8 string
3. Parse with `swift-markdown` (GFM options: tables, task lists, strikethrough, autolinks)
4. Walk AST with a custom `MarkupWalker` that emits HTML fragments
5. Wrap in a full HTML page template with embedded CSS
6. Load into `WKWebView` via `loadHTMLString(_:baseURL:)`

**Tab bar (Rendered / Source):**
- Two-segment control at the top of the preview panel
- "Rendered" — full HTML output in the web view
- "Source" — raw markdown in a `<pre><code>` block with system monospace font
- Default tab comes from user settings (App Groups `UserDefaults`)
- Tab state is local to each preview session, not persisted

**Supported file extensions:** `.md`, `.markdown`, `.mdown`, `.mkd`, `.mkdn`, `.mdtext`, `.mdtxt`

**UTI declarations:** Extension declares `net.daringfireball.markdown` and relevant `public.plain-text` subtypes. Host app `Info.plist` imports the markdown UTI for systems that don't register it natively.

**Performance:** No lazy loading needed. For typical files (< 100 KB) the pipeline is effectively instant.

---

## Section 3: Host App UI

**Window:** Fixed size (~400pt wide), not resizable. Built with SwiftUI's `.formStyle(.grouped)` — the macOS-native settings panel pattern.

**Layout:**

### Header (above the form)
- `Image(nsImage: NSApp.applicationIconImage)` + `Text("show.md")` in `.title2 + .semibold`
- Tagline in `.caption + .secondary`
- Version string in `.caption2 + .tertiary`
- Centered, `24pt` top padding, `16pt` bottom padding before form

### Form — Section 1: "Preview"
- `Toggle("Enable Quick Look Preview", isOn: $isEnabled)` — full built-in Toggle label (no `.labelsHidden()`). Reads current extension enabled state; deep-links to `x-apple.systempreferences:com.apple.ExtensionsPreferences` when the user needs to confirm in System Settings.
- `Picker("Default Tab", selection: $defaultTab)` — `.segmented` style, options: `Rendered` / `Source`

### Form — Section 2: "Appearance"
- `Picker("Theme", selection: $theme)` — `.segmented` style, options: `Auto` / `Light` / `Dark`
- `Picker("Font Size", selection: $fontSize)` — `.segmented` style, options: `Small` / `Medium` / `Large`

> All pickers use a single selected value (not multiple toggles) — mutually exclusive choices per SwiftUI design principles.

### Footer (below the form)
- `HStack(spacing: 16)` centered: `Button("Buy me a pasta ☕")` + `Button("GitHub")`, both `.buttonStyle(.link)`, `.caption` font, `16pt` top padding

**Spacing:** All values from the 4/8 grid (8, 12, 16, 24). Section spacing handled natively by `.formStyle(.grouped)`.

**Colors:** Entirely semantic — `Color(.secondarySystemBackground)` for groups, `.primary` / `.secondary` / `.tertiary` for text. No hardcoded colors.

**Settings storage:** All settings written to `UserDefaults(suiteName: "group.com.yourteam.show-md")` so the extension picks them up immediately without IPC.

---

## Section 4: Rendering Pipeline & CSS Theming

### HTML template

```html
<!DOCTYPE html>
<html data-theme="auto|light|dark">
<head>
  <meta charset="UTF-8">
  <meta name="color-scheme" content="light dark">
  <style>/* embedded CSS */</style>
</head>
<body>
  <!-- rendered markdown HTML -->
</body>
</html>
```

`data-theme` is set at render time from the user's theme setting.

### CSS theming strategy

Three-layer CSS custom properties — no JavaScript required:

```css
/* Layer 1: follow system */
:root {
  --bg: #ffffff;
  --text: #1a1a1a;
  --code-bg: #f5f5f5;
  --border: #e0e0e0;
}
@media (prefers-color-scheme: dark) {
  :root { --bg: #1e1e1e; --text: #e8e8e8; --code-bg: #2a2a2a; --border: #3a3a3a; }
}

/* Layer 2: user forces light */
[data-theme="light"] { --bg: #ffffff; --text: #1a1a1a; --code-bg: #f5f5f5; --border: #e0e0e0; }

/* Layer 3: user forces dark */
[data-theme="dark"] { --bg: #1e1e1e; --text: #e8e8e8; --code-bg: #2a2a2a; --border: #3a3a3a; }
```

### Typography

- Body: `-apple-system`, root `font-size` driven by user setting (`13px` small / `15px` medium / `17px` large), `1.6` line-height
- Headings: weight differentiation — `h1` at `1.6em`, `h2` at `1.35em`, `h3` at `1.15em`
- Code: `ui-monospace` (SF Mono), `0.875em`, `var(--code-bg)` background, `6px` border-radius, `16px` padding

### GFM element handling

| Element | Approach |
|---|---|
| Tables | `<table>` with `border-collapse`, alternating row `var(--code-bg)` tint |
| Task lists | `<input type="checkbox" disabled>` — read-only native checkbox |
| Strikethrough | `<del>`, `text-decoration: line-through` |
| Autolinks | `<a>` with `pointer-events: none` — links are non-clickable in preview |

### Source tab

Raw markdown injected into `<pre><code>` block. Same page template, same font size setting. `ui-monospace`, `var(--code-bg)` background, `16px` padding, `word-wrap: break-word`. No syntax highlighting.

---

## Section 5: Settings Schema

All keys stored in `UserDefaults(suiteName: "group.com.yourteam.show-md")`.

| Key | Type | Default | Values |
|---|---|---|---|
| `defaultTab` | `String` | `"rendered"` | `"rendered"`, `"source"` |
| `theme` | `String` | `"auto"` | `"auto"`, `"light"`, `"dark"` |
| `fontSize` | `String` | `"medium"` | `"small"`, `"medium"`, `"large"` |

String-typed enums — survives future reordering without data migration. Extension reads on every preview load; missing keys fall back to defaults above. No versioning needed for v1.

---

## Section 6: Build, Signing & Release Pipeline

### Signing
- Both targets signed with the same **Developer ID Application** certificate
- App Groups entitlement (`com.apple.security.application-groups`) on both targets
- Hardened Runtime enabled on host app (required for notarization)

### Notarization flow
```sh
# 1. Archive + export as Developer ID in Xcode
# 2. Submit for notarization
xcrun notarytool submit show.md.zip \
  --apple-id <email> --team-id <team> --password <app-specific-pw> --wait
# 3. Staple
xcrun stapler staple show.md.app
# 4. Package for distribution
ditto -c -k --sequesterRsrc --keepParent show.md.app show.md.zip
```

### GitHub Release
- Tag format: `v1.0.0`
- Release asset: `show.md.zip` (notarized + stapled)
- Checksum: `show.md.zip.sha256` (required for Homebrew cask)

---

## Section 7: Homebrew Cask

Initial distribution via a personal tap; submit to `homebrew/homebrew-cask` once the app has traction.

```ruby
cask "show-md" do
  version "1.0.0"
  sha256 "<sha256-of-release-zip>"

  url "https://github.com/<user>/show.md/releases/download/v#{version}/show.md.zip"
  name "show.md"
  desc "Quick Look extension for Markdown files"
  homepage "https://github.com/<user>/show.md"

  app "show.md.app"

  zap trash: [
    "~/Library/Preferences/group.com.yourteam.show-md.plist",
  ]
end
```

The `zap` stanza removes the shared `UserDefaults` plist (written to `~/Library/Preferences/` by the App Groups suite) on uninstall.
