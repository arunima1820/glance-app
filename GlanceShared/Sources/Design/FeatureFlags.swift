import Foundation

// MARK: - FeatureFlags
/// Experiment-worthy knobs in one struct. Views read these instead of hard-coding
/// behavior, so an A/B arm or remote toggle flips a value here, not call sites.
struct FeatureFlags: Sendable, Equatable {
    /// Shows the Food tab.
    var groceriesTabVisible: Bool = true

    static let `default` = FeatureFlags()
}

// MARK: - FeatureFlagProvider
/// Source of the active flags. `StaticFlags` ships now; a remote / A-B provider
/// conforms to this later and drops in with no call-site changes.
protocol FeatureFlagProvider: Sendable {
    var flags: FeatureFlags { get }
}

/// The flags compiled into the app.
struct StaticFlags: FeatureFlagProvider {
    let flags: FeatureFlags
    init(_ flags: FeatureFlags = .default) { self.flags = flags }
}
