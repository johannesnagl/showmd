# Lessons Learned — showmd

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

### NEVER use [weak self] in preparePreviewOfFile dispatch closures

**CRITICAL: The dispatch closures inside `preparePreviewOfFile` MUST capture `self` strongly (no `[weak self]`).** These are one-shot blocks, not stored closures — there is no retain cycle.

The Quick Look framework can release the view controller after calling `preparePreviewOfFile`. The view stays in the window hierarchy (toolbar visible), but the view controller is deallocated. With `[weak self]`, the main-queue callback sees `self == nil` and returns early without loading any content → **blank preview**.

This caused a production regression: the toolbar rendered correctly but the WKWebView was completely empty.

```swift
// WRONG — causes blank previews
DispatchQueue.global(qos: .userInitiated).async { [weak self] in
    ...
    DispatchQueue.main.async { [weak self] in
        guard let self else { handler(nil); return }  // ← silently bails out
        self.loadCombined()
    }
}

// CORRECT — strong self keeps VC alive until content loads
DispatchQueue.global(qos: .userInitiated).async {
    ...
    DispatchQueue.main.async {
        self.loadCombined()
        handler(nil)
    }
}
```

`[weak self]` IS appropriate for long-lived or stored closures (e.g. `DispatchQueue.main.asyncAfter` in `copyAsHTML`) where you genuinely don't need self if it's gone.

### NEVER remove com.apple.security.network.client from the extension entitlements

**CRITICAL: WKWebView requires `com.apple.security.network.client` in sandboxed macOS apps — even for `loadHTMLString` with purely local/inline content.** Without this entitlement, `loadHTMLString` silently fails: no error, no delegate callback, no crash — the WKWebView simply renders nothing.

This caused a multi-hour production debugging session. The entitlement was removed with the reasoning "we bundle everything offline, no network needed." While the *app* doesn't need network access, WKWebView's internal WebContent subprocess requires the entitlement to communicate with the host process.

**Rule: Never remove entitlements from `ShowMdExtension.entitlements` without testing the Quick Look preview end-to-end in Finder.**

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
- **Always commit all pending changes when the user asks.** Don't leave work uncommitted across sessions. Group related changes into a single descriptive commit.

---

## UTType Declarations for Custom File Extensions

To support non-standard markdown extensions (`.mdx`, `.mdc`, `.rmd`, `.qmd`, `.mdown`, `.mkd`, `.mkdn`, `.mdtext`, `.mdtxt`):

1. Declare `UTImportedTypeDeclarations` in the **host app's** `ShowMd/Info.plist` — this registers the custom UTTypes with the system.
2. Add the custom UTType identifiers to `QLSupportedContentTypes` in `ShowMdExtension/Info.plist` — this tells the Quick Look extension to handle them.
3. Use a consistent naming convention: `io.github.showmd.<ext>` for the UTType identifiers.
4. Each UTType must conform to `public.plain-text` and specify `public.filename-extension` in `UTTypeTagSpecification`.

---

## Rich Feature Rendering (Syntax Highlighting, KaTeX, Mermaid)

- All JS/CSS dependencies are bundled locally in the Swift package `Resources/` directory and loaded via `Bundle.module` → `ResourceLoader`. No CDN, no network — fully offline rendering.
- Resources: highlight.min.js, github.min.css, github-dark.min.css, katex.min.js, katex.min.css (with base64-encoded WOFF2 fonts), auto-render.min.js, mermaid.min.js.
- Mermaid blocks require special handling in `HTMLVisitor`: detect `language == "mermaid"` and emit `<pre class="mermaid">` instead of `<pre><code class="language-mermaid">`.
- Syntax highlighting is restricted to code blocks with an explicit language class (`pre code[class*="language-"]`) to avoid highlighting plain code blocks.
- KaTeX auto-render uses `$...$` (inline) and `$$...$$` (block) delimiters, with `ignoredTags` to avoid rendering inside `<pre>`, `<code>`, etc.

---

## Security — XSS Prevention

**CRITICAL: Every piece of user-supplied content that ends up in HTML output MUST be escaped.** This is non-negotiable. XSS in a Quick Look extension means any `.md` file on the filesystem can execute arbitrary JavaScript in the WKWebView.

### Mandatory rules

1. **Always use `HTMLEscape.escape()` on any string interpolated into HTML** — text content, attributes, URLs, code block content, language attributes, everything.
2. **Never trust raw HTML from markdown files.** Use `sanitizeHTML()` to strip `<script>`, `<iframe>`, event handlers (`on*=`), and `javascript:` URLs. Only safe structural tags pass through.
3. **Never interpolate unescaped values into JavaScript strings** — e.g. `evaluateJavaScript("document.className = '\(value)'")`. Escape or use a fixed enum.
4. **HTMLEscape must cover all 5 chars:** `&`, `<`, `>`, `"`, `'` (single quotes matter for attributes and JS strings).
5. **Every new rendering path needs an XSS test** — if you add a new code block language, a new post-processor, or a new template interpolation, write a test that tries to inject `<script>alert(1)</script>` and verifies it's escaped or stripped.

### Past incidents

- Math code blocks (`\`\`\`math`) passed `codeBlock.code` raw into HTML — a crafted `.md` file could inject `<script>` tags.
- Raw HTML passthrough (`visitHTMLBlock`/`visitInlineHTML`) echoed untrusted HTML verbatim — any `<script>` in a `.md` file executed.
- Code block language attribute was interpolated unescaped into `class="language-..."` — allowed attribute injection.
- `HTMLEscape` was missing single-quote escaping — left single-quoted HTML/JS contexts vulnerable.
- Autolinks double-escaped already-escaped URLs producing `&amp;amp;` — text segments from the visitor are already escaped.

---

## Testing

**Tests are vital and must never be forgotten.** Every new feature or behavioral change to the `MarkdownRenderer` package MUST have corresponding tests before committing. No exceptions.

### Test coverage requirements

When adding a feature, always add tests for:
1. The **happy path** — basic functionality works
2. **Edge cases** — empty input, special characters, HTML escaping
3. **XSS vectors** — try injecting `<script>`, event handlers, and `javascript:` URLs through every input path
4. **Negative cases** — e.g. source-only template should NOT include rich feature scripts

### Current test suites (51 tests total)

| Suite | What it covers |
|-------|---------------|
| `HTMLVisitorTests` | Every markdown element → HTML conversion: text, bold, italic, inline code, links, images, headings, code blocks (plain + language-specific + mermaid), blockquotes, lists, tables, task lists, strikethrough, HTML escaping |
| `HTMLTemplateTests` | Template wrapping: DOCTYPE, body injection, theme attribute, font size, source body class, color-scheme meta, rich feature CDN inclusion (highlight.js, KaTeX, Mermaid), combined template tabs, frontmatter HTML |
| `MarkdownRendererTests` | Public API: full render, theme application, font size, source HTML escaping |
| `SettingsTests` | UserDefaults round-trips for all settings, defaults, CSS values, unknown raw value fallback |

### Running tests

```bash
cd MarkdownRenderer && swift test
```

### Test markdown fixture files

The `tests/fixtures/` directory contains comprehensive `.md` files that exercise every renderer feature (alerts, XML tags, code blocks, math, mermaid, frontmatter, emoji, etc.). After making rendering changes, open these files in Finder and press Space to verify Quick Look output. Keep these files up to date when adding new features.

### What's NOT yet tested (future work)

- `renderCombined()` public API (combines rendered + source views)
- `renderBody()` public API (returns HTML body without template wrapper)
- Frontmatter parsing integration (YAML → metadata table)
- WKWebView rendering (requires UI test target, not unit-testable in SPM)

---

## Website — Accessibility, Performance, SEO & Mobile Standards

**Every website change MUST follow these rules.** This is a checklist, not a suggestion.

### Accessibility (WCAG AA)

1. **Every `<section>` needs an accessible name** — use `aria-labelledby` pointing to a heading with an `id`, or `aria-label` for decorative sections.
2. **Use semantic HTML** — `<h2>` not `<p>` for section headings; `<nav>`, `<main>`, `<footer>` for landmarks. Decorative elements get `aria-hidden="true"`.
3. **Color contrast: WCAG AA minimum (4.5:1 for text, 3:1 for large text)** — test dark AND light mode. Use theme-aware CSS variables (`--btn-bg`/`--btn-fg`) for buttons, never hardcoded `var(--white)` on potentially white backgrounds.
4. **`prefers-reduced-motion`** — all animations and transitions must have a `reduce` override. Auto-cycling content must stop after one rotation (WCAG 2.2.2).
5. **Keyboard navigation** — all interactive elements must be reachable via Tab. Hidden decorative links need `tabindex="-1"`. FAQ accordion buttons need `aria-expanded` + `aria-controls`.
6. **Focus styles** — use `:focus-visible` with a visible outline (`2px solid var(--accent)`).

### Performance

1. **No FOUC** — theme detection script runs in `<head>` as a blocking inline `<script>`, not at end of body.
2. **Font loading** — use `font-display: swap` (via Google Fonts `&display=swap`), preconnect to font origins.
3. **No render-blocking CSS** — critical styles are inlined; everything else is in a single `<style>` block (no external CSS files).
4. **Images** — use `width`/`height` or `aspect-ratio` to prevent layout shifts. Favicon set: SVG + 32px PNG + 180px apple-touch-icon + webmanifest.

### SEO & Social

1. **OG image must be PNG** (not SVG) — social platforms don't render SVG. Dimensions in meta tags must match the actual file.
2. **Structured data** — `SoftwareApplication` + `FAQPage` schemas in `<script type="application/ld+json">`.
3. **Canonical URL**, title, description, Twitter card, and OG tags are all required.
4. **All external links** get `rel="noopener" target="_blank"`.

### Mobile (max-width: 640px)

1. **Preview scene must fit** — reduce height, hide sidebar, adapt app frame to full width.
2. **Buttons** — full width on mobile (`width: 100%`), stack vertically.
3. **Typography** — clamp hero title (`font-size: 28px` on mobile), reduce section padding.
4. **Navigation** — hide nav links, keep logo + CTA.
5. **Install section** — stack rows vertically.
6. **Test on actual phones** — the 640px breakpoint is the minimum; verify nothing overflows horizontally.

### Past incidents

- Buttons used `background: var(--white)` which is always `#FFFFFF` — invisible on light backgrounds. Fixed with `--btn-bg`/`--btn-fg` tokens.
- Theme script at bottom of body caused FOUC — all variables flashed dark values on light-mode systems.
- Missing `favicon-32.png` and `apple-touch-icon.png` caused 404s on every page load.
- OG image was SVG — showed broken/missing image on Twitter, Facebook, LinkedIn.
- Preview scene had fixed 480px height — overflowed and clipped on mobile screens.
- Inline `onclick` on brew button — moved to `addEventListener` for CSP compatibility.
- Auto-cycling preview ran indefinitely — violated WCAG 2.2.2 requirement.

---

## Release Checklist (when ready)

1. Set DEVELOPMENT_TEAM in Xcode for both targets
2. Archive → Distribute → Developer ID
3. `xcrun notarytool submit ... --wait`
4. `xcrun stapler staple showmd.app`
5. `ditto -c -k --sequesterRsrc --keepParent showmd.app showmd-VERSION.zip`
6. `shasum -a 256 showmd-VERSION.zip` → use in Homebrew cask
7. `git tag vVERSION && git push origin main --tags`
8. Create GitHub release, upload zip + sha256
9. Update `Casks/show-md.rb` in homebrew-tap repo
