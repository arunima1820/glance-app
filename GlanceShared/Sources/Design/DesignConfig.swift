import SwiftUI

// MARK: - DesignConfig
/// The single source of truth for look & behavior, injected into the view tree.
/// Swap `paletteSchemeID`, `fontThemeID`, or `flags` to re-skin or re-tune the whole
/// app — the hooks a future A/B / feature-toggle layer will drive.
///
/// A plain `ObservableObject` (not `@MainActor`) so its shared default can seed a
/// SwiftUI `EnvironmentKey`, whose `defaultValue` is required to be nonisolated.
final class DesignConfig: ObservableObject {
    @Published var paletteSchemeID: PaletteSchemeID
    @Published var fontThemeID: FontThemeID
    @Published private(set) var flags: FeatureFlags

    init(
        paletteSchemeID: PaletteSchemeID = Palettes.default,
        fontThemeID: FontThemeID = FontThemes.default,
        flagProvider: FeatureFlagProvider = StaticFlags()
    ) {
        self.paletteSchemeID = paletteSchemeID
        self.fontThemeID = fontThemeID
        self.flags = flagProvider.flags
    }

    /// Resolves the palette for the current appearance.
    func palette(for scheme: ColorScheme) -> Palette {
        Palettes.scheme(paletteSchemeID).palette(for: scheme)
    }

    /// The active font theme.
    var fontTheme: FontTheme { FontThemes.theme(fontThemeID) }

    /// Shared default for contexts without an environment (e.g. the widget).
    /// `nonisolated(unsafe)`: one immutable reference, read/mutated on the main thread
    /// by SwiftUI — a guarantee the compiler can't prove, so we assert it here.
    nonisolated(unsafe) static let shared = DesignConfig()
}

// MARK: - Environment wiring
private struct DesignConfigKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = DesignConfig.shared
}

extension EnvironmentValues {
    /// Read the active config in any view: `@Environment(\.design) var design`.
    var design: DesignConfig {
        get { self[DesignConfigKey.self] }
        set { self[DesignConfigKey.self] = newValue }
    }
}

// MARK: - Resolved style environment
/// Views read the *resolved* palette and fonts from the environment, so they never touch
/// DesignConfig or ColorScheme directly. `glanceStyled()` fills these in at the root.
private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = Palettes.fridgeMarker.light
}
private struct FontsKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: FontTheme = MarkerFontTheme()
}

extension EnvironmentValues {
    /// The active palette, already resolved for light/dark.
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
    /// The active font theme.
    var fonts: FontTheme {
        get { self[FontsKey.self] }
        set { self[FontsKey.self] = newValue }
    }
}

// MARK: - glanceStyled
/// Root modifier: injects the config as an environment object and publishes the palette/fonts
/// resolved for the current appearance. Apply once, high in the tree (app + widget roots).
private struct GlanceStyled: ViewModifier {
    @ObservedObject var design: DesignConfig
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .environmentObject(design)
            .environment(\.palette, design.palette(for: scheme))
            .environment(\.fonts, design.fontTheme)
    }
}

extension View {
    /// Applies Glance's resolved palette + fonts (and shares the config) to this subtree.
    func glanceStyled(_ design: DesignConfig = .shared) -> some View {
        modifier(GlanceStyled(design: design))
    }
}
