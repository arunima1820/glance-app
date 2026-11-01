import Foundation

// MARK: - FeatureFlags
/// Experiment-worthy knobs in one struct. Views read these instead of hard-coding
/// behavior, so an A/B arm or remote toggle flips a value here, not call sites.
struct FeatureFlags: Sendable, Equatable {
    var defaultCompletionStyle: ThemeCompletionStyle = .sweep
    var themeIconsOnByDefault: Bool = true
    var groceriesTabVisible: Bool = true
    var survivalRecipesEnabled: Bool = false   // v2 (ML)
    var cameraFoodEnabled: Bool = false        // v2 (ML)

    static let `default` = FeatureFlags()
}

// MARK: - FeatureFlagProvider
/// Source of the active flags. `StaticFlags` ships now; a remote / A-B provider
/// conforms to this later and drops in with no call-site changes.
protocol FeatureFlagProvider: Sendable {
    var flags: FeatureFlags { get }
}

struct StaticFlags: FeatureFlagProvider {
    let flags: FeatureFlags
    init(_ flags: FeatureFlags = .default) { self.flags = flags }
}
