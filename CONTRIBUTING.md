# Contributing to showmd

Thanks for your interest in contributing! Please follow these guidelines.

## Rules

1. **All changes must have tests.** Every new feature, bug fix, or behavioral change to the `MarkdownRenderer` package requires corresponding unit tests. No exceptions.

2. **PRs are only accepted with green CI.** All tests must pass in the GitHub Actions workflow before a PR will be reviewed or merged.

3. **AI-generated PRs must check `tasks/lessons.md` and `CLAUDE.md`.** If your PR was generated with the help of an AI coding assistant, you must review both `tasks/lessons.md` and the root `CLAUDE.md` for known pitfalls, project rules, and coding guidelines. Ensure your changes don't violate any of the documented lessons or instructions.

4. **Run tests locally before pushing:**
   ```bash
   cd MarkdownRenderer && swift test
   ```

5. **XSS prevention is mandatory.** All user-supplied content rendered in HTML must be escaped. See the "Security -- XSS Prevention" section in `tasks/lessons.md` for details. Every new rendering path needs an XSS test.

6. **Never remove entitlements without end-to-end testing.** Entitlement changes to `ShowMdExtension.entitlements` must be verified by testing Quick Look preview in Finder. See `tasks/lessons.md` for past incidents.

## Development Setup

1. Install [XcodeGen](https://github.com/yonaskolb/xcodegen): `brew install xcodegen`
2. Generate the Xcode project: `xcodegen generate`
3. Open `showmd.xcodeproj` in Xcode
4. Set your Development Team in Signing & Capabilities for both targets

## Running Tests

```bash
cd MarkdownRenderer && swift test
```

The Swift package uses `swift-tools-version: 5.9` and targets macOS 26.0.

## Test Markdown Files

The `tests/fixtures/` directory contains comprehensive markdown files that exercise all renderer features. Use these to manually verify rendering in Finder's Quick Look preview after making changes.

## Commit Guidelines

- One commit per logical change
- Write clear, descriptive commit messages
- Group related changes into a single commit
