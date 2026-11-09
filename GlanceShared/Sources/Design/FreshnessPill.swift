import SwiftUI

// MARK: - FreshnessPill
/// The small "3 days" / "today" / "expired" pill, used by food tiles, the food screen and every
/// widget. Draws nothing for `.none` (canned).
///
/// Paper: dark ink on a soft tint (7.8–8.9:1). Chalkboard: calm chalk outlines for days and
/// weeks, and a solid chalk fill only when it's urgent (expired, today), all ≥4.8:1.
struct FreshnessPill: View {
    @Environment(\.colorScheme) private var scheme
    let freshness: Freshness
    let palette: Palette
    /// Fixed text size (widgets). nil = follows the iPhone's text size (the app).
    var fixedSize: CGFloat?

    var body: some View {
        if freshness != .none {
            let style = PillStyle.of(freshness, palette: palette, dark: scheme == .dark)
            Text(freshness.label)
                .font(font)
                .foregroundStyle(style.text)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(style.fill, in: Capsule())
                .overlay(Capsule().stroke(style.outline, lineWidth: 1.2))
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)   // grows, but never breaks a tile
                .accessibilityLabel(freshness.spokenLabel)
        }
    }

    /// Fixed for widgets; Dynamic Type (caption2) in the app.
    private var font: Font {
        if let fixedSize { return .system(size: fixedSize, weight: .heavy, design: .rounded) }
        return .system(.caption2, design: .rounded, weight: .heavy)
    }
}

// MARK: - PillStyle
/// The three colours of a pill for one state and mode.
struct PillStyle: Equatable {
    let text: Color
    let fill: Color
    let outline: Color

    /// Picks the pill colours.
    /// - Parameters:
    ///   - freshness: the state.
    ///   - palette: the active palette.
    ///   - dark: chalkboard (dark) mode.
    static func of(_ freshness: Freshness, palette: Palette, dark: Bool) -> PillStyle {
        let chalk = chalkColor(freshness, palette)
        guard dark else {
            // Paper: dark ink on a soft tint of the same colour.
            let tint = isDays(freshness) ? 0.6 : 0.45
            return PillStyle(text: Palettes.fridgeMarker.light.ink, fill: chalk.opacity(tint), outline: .clear)
        }
        if isUrgent(freshness) {
            return PillStyle(text: palette.paper, fill: chalk, outline: .clear)
        }
        return PillStyle(text: chalk, fill: .clear, outline: chalk)
    }

    /// Expired or due today: the only states that get a solid chalk fill on the board.
    static func isUrgent(_ freshness: Freshness) -> Bool {
        freshness == .expired || freshness == .days(0)
    }

    /// Any "N days" state, including today.
    private static func isDays(_ freshness: Freshness) -> Bool {
        if case .days = freshness { return true }
        return false
    }

    /// Marker for expired, mustard for days (incl. today), avocado for weeks.
    private static func chalkColor(_ freshness: Freshness, _ palette: Palette) -> Color {
        switch freshness {
        case .expired: return palette.marker
        case .days: return palette.mustard
        case .weeks: return palette.avocado
        case .none: return .clear
        }
    }
}
