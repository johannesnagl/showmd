import Foundation

public struct Settings {
    private static let suiteName = "group.one.yetanother.showmd"

    /// Both the sandboxed extension and non-sandboxed host app use UserDefaults
    /// backed by the App Group container. `containerURL(forSecurityApplicationGroupIdentifier:)`
    /// resolves to the same `~/Library/Group Containers/<group>/` regardless of sandbox state,
    /// and addPersistentDomain ensures UserDefaults reads/writes there.
    public static var userDefaults: UserDefaults = {
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        // Force sync to pick up changes from the other process
        defaults.synchronize()
        return defaults
    }()

    /// Call this to re-read values that may have been written by the other process.
    public static func reload() {
        userDefaults.synchronize()
    }

    public enum Tab: String, CaseIterable {
        case rendered, source
    }

    public enum Theme: String, CaseIterable {
        case auto, light, dark
    }

    public enum FontSize: String, CaseIterable {
        case small, medium, large

        public var cssValue: String {
            switch self {
            case .small:  return "13px"
            case .medium: return "15px"
            case .large:  return "17px"
            }
        }
    }

    public static var defaultTab: Tab {
        get { Tab(rawValue: userDefaults.string(forKey: "defaultTab") ?? "") ?? .rendered }
        set { userDefaults.set(newValue.rawValue, forKey: "defaultTab"); userDefaults.synchronize() }
    }

    public static var theme: Theme {
        get { Theme(rawValue: userDefaults.string(forKey: "theme") ?? "") ?? .auto }
        set { userDefaults.set(newValue.rawValue, forKey: "theme"); userDefaults.synchronize() }
    }

    public static var fontSize: FontSize {
        get { FontSize(rawValue: userDefaults.string(forKey: "fontSize") ?? "") ?? .medium }
        set { userDefaults.set(newValue.rawValue, forKey: "fontSize"); userDefaults.synchronize() }
    }

    public static var mermaidEnabled: Bool {
        get { userDefaults.object(forKey: "mermaidEnabled") as? Bool ?? false }
        set { userDefaults.set(newValue, forKey: "mermaidEnabled"); userDefaults.synchronize() }
    }
}
