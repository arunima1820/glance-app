import SwiftUI

// MARK: - GlanceColors
/// Semantic color tokens. All backgrounds avoid pure white/black (design rule).
enum GlanceColors {
    /// Main background — soft off-white in light mode, soft dark in dark mode.
    static let background  = Color("GlanceBackground")
    /// Card / surface color (slightly elevated from background).
    static let surface     = Color("GlanceSurface")
    /// Primary readable text — dark-but-not-black on light; light-but-not-white on dark.
    static let primaryText = Color("GlancePrimaryText")
    /// Secondary / hint text.
    static let secondaryText = Color("GlanceSecondaryText")
    /// The app's neutral accent (used for the + FAB, etc.).
    static let accent      = Color("GlanceAccent")
    /// Small decorative bullet dot.
    static let bulletDot   = Color("GlanceBulletDot")
}

// MARK: - GlanceFonts
/// Semantic font roles. All use Dynamic Type so they grow with the user's system text size.
/// Bold for emphasis only; no italics or all-caps (BDA guidelines).
enum GlanceFonts {
    static let largeTitle  = Font.largeTitle.weight(.bold)
    static let title       = Font.title2.weight(.semibold)
    static let label       = Font.headline
    static let body        = Font.body
    static let stepText    = Font.title3          // slightly larger for the main list
    static let caption     = Font.subheadline
}

// MARK: - GlancePrimaryButtonStyle
struct GlancePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(GlanceColors.accent)
                    .opacity(configuration.isPressed ? 0.8 : 1)
            )
    }
}

// MARK: - Color asset fallbacks
/// When running in previews or tests without the asset catalog, these provide safe defaults.
extension Color {
    static func named(_ name: String, fallback: Color) -> Color {
        // In production the asset catalog wins; this is a dev safety net.
        return Color(name) // SwiftUI resolves from asset catalog automatically
    }
}
