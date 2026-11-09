import Foundation

// MARK: - StorageKeys
/// Every UserDefaults / AppStorage key in one place, so a key is never mistyped in two spots.
enum StorageKeys {
    // Shared with the widget (App Group defaults, `WidgetDataBridge.defaults`).
    /// The list snapshot the widget draws.
    static let widgetSnapshot = "glance.widget.snapshot"
    /// The list the user pinned to the widget.
    static let widgetPinnedTheme = "glance.widget.pinnedThemeID"
    /// When the user last pinned or unpinned.
    static let widgetPinnedAt = "glance.widget.pinnedAt"
    /// Settings → Title style.
    static let fontTheme = "glance.fontTheme"
    /// The food snapshot the widgets draw.
    static let widgetFood = "glance.widget.food"
    /// Settings → "Hide details on Lock Screen".
    static let lockScreenHidesDetails = "glance.widget.lockScreenHidesDetails"

    // App only (standard defaults).
    /// Onboarding has been seen.
    static let hasSeenOnboarding = "hasSeenOnboarding"
    /// Settings → Look.
    static let appearance = "glance.appearance"
    /// Set when the store had to be reset ("reset") or run in memory ("temporary"); the app
    /// tells the user once, then clears it.
    static let storeNotice = "glance.storeNotice"
    /// The tab open when the app was last used (reopens there).
    static let lastTab = "glance.lastTab"
    /// Food tab sort order.
    static let foodSort = "glance.food.sort"
    /// The last few deleted lists.
    static let removedLists = "glance.removed.lists"
    /// The last few used-up or deleted foods.
    static let removedFood = "glance.removed.food"
}

// MARK: - AppInfo
/// The single place the displayed app name lives.
enum AppInfo {
    static let displayName = "Glance"
}
