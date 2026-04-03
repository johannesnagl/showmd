import Testing
import Foundation

/// Guards against accidental removal of required entitlements.
/// WKWebView silently fails to render in sandboxed macOS apps without
/// com.apple.security.network.client — even for loadHTMLString with local content.
@Suite struct EntitlementsTests {
    /// Locates the repo root by walking up from the test bundle or current directory.
    private func repoRoot() throws -> URL {
        // When run via `swift test` inside MarkdownRenderer/, the cwd is MarkdownRenderer/
        // The repo root is one level up.
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<5 {
            let candidate = dir.appendingPathComponent("ShowMdExtension/ShowMdExtension.entitlements")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }
        throw EntitlementsError.repoRootNotFound
    }

    private enum EntitlementsError: Error {
        case repoRootNotFound
    }

    private func loadEntitlements(at relativePath: String) throws -> [String: Any] {
        let root = try repoRoot()
        let url = root.appendingPathComponent(relativePath)
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return plist as? [String: Any] ?? [:]
    }

    @Test func extensionHasNetworkClientEntitlement() throws {
        let entitlements = try loadEntitlements(at: "ShowMdExtension/ShowMdExtension.entitlements")
        let hasNetworkClient = entitlements["com.apple.security.network.client"] as? Bool ?? false
        #expect(hasNetworkClient, """
            CRITICAL: com.apple.security.network.client is REQUIRED in ShowMdExtension.entitlements.
            WKWebView silently fails to render ANY content without this entitlement,
            even for loadHTMLString with purely local/inline HTML.
            Do NOT remove this entitlement — it caused a multi-hour debugging session.
            """)
    }

    @Test func extensionHasAppSandbox() throws {
        let entitlements = try loadEntitlements(at: "ShowMdExtension/ShowMdExtension.entitlements")
        let hasSandbox = entitlements["com.apple.security.app-sandbox"] as? Bool ?? false
        #expect(hasSandbox, "Extension must have app-sandbox entitlement")
    }

    @Test func extensionHasAppGroups() throws {
        let entitlements = try loadEntitlements(at: "ShowMdExtension/ShowMdExtension.entitlements")
        let groups = entitlements["com.apple.security.application-groups"] as? [String] ?? []
        #expect(groups.contains("group.io.github.show-md"),
                "Extension must have App Groups entitlement for settings sharing")
    }

    @Test func hostAppHasAppGroups() throws {
        let entitlements = try loadEntitlements(at: "ShowMd/ShowMd.entitlements")
        let groups = entitlements["com.apple.security.application-groups"] as? [String] ?? []
        #expect(groups.contains("group.io.github.show-md"),
                "Host app must have App Groups entitlement for settings sharing")
    }
}
