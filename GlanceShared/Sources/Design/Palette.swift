import SwiftUI

// MARK: - Palette
/// The full set of color roles the UI draws from. Screens reference roles
/// (e.g. `palette.ink`), never raw hex, so a whole look can be swapped at once.
struct Palette: Sendable, Equatable {
    let paper: Color        // app background
    let card: Color         // list / card surface
    let ink: Color          // primary text & borders
    let ink2: Color         // secondary text
    let marker: Color       // accent
    let markerDeep: Color   // primary-button fill (white text sits on this)
    let avocado: Color      // secondary accent / magnets
    let mustard: Color      // highlight / washi tape
    let sky: Color          // accent
    let hairline: Color     // row dividers
}

// MARK: - PaletteScheme
/// A light + dark pairing, identified so experiments can swap the whole scheme.
struct PaletteScheme: Identifiable, Sendable {
    let id: PaletteSchemeID
    let displayName: String
    let light: Palette
    let dark: Palette

    /// Resolves the right `Palette` for the active system appearance.
    func palette(for scheme: ColorScheme) -> Palette {
        scheme == .dark ? dark : light
    }
}

enum PaletteSchemeID: String, CaseIterable, Sendable {
    case fridgeMarker   // the locked default; add alternates here for A/B
}

// MARK: - Palettes registry
/// All available schemes + the current default. Add a scheme here to make it
/// selectable; nothing else in the app hard-codes colors.
enum Palettes {
    static let `default`: PaletteSchemeID = .fridgeMarker

    static func scheme(_ id: PaletteSchemeID) -> PaletteScheme {
        switch id {
        case .fridgeMarker: return fridgeMarker
        }
    }

    // Locked "Fridge & Marker" — paper whiteboard (light) / chalkboard (dark).
    static let fridgeMarker = PaletteScheme(
        id: .fridgeMarker,
        displayName: "Fridge & Marker",
        light: Palette(
            paper:      Color(hex: "#F4ECD8"),
            card:       Color(hex: "#FFFDF6"),
            ink:        Color(hex: "#2B2A26"),
            ink2:       Color(hex: "#726A58"),
            marker:     Color(hex: "#C65D3B"),
            markerDeep: Color(hex: "#B14A2C"),
            avocado:    Color(hex: "#6B7B3A"),
            mustard:    Color(hex: "#D9A441"),
            sky:        Color(hex: "#5E86A3"),
            hairline:   Color(hex: "#2B2A26").opacity(0.13)
        ),
        dark: Palette(
            paper:      Color(hex: "#243029"),
            card:       Color(hex: "#2B382F"),
            ink:        Color(hex: "#ECE7D8"),
            ink2:       Color(hex: "#A9B0A0"),
            marker:     Color(hex: "#E88A6F"),
            markerDeep: Color(hex: "#E88A6F"),
            avocado:    Color(hex: "#A7C58A"),
            mustard:    Color(hex: "#E6C878"),
            sky:        Color(hex: "#9BC2D6"),
            hairline:   Color(hex: "#ECE7D8").opacity(0.15)
        )
    )
}

// MARK: - ThemeIcon
/// A theme's identity glyph, mapped to an SF Symbol (crisp, Dynamic-Type aware, never emoji).
/// Stored on a Theme by its `id` token, so the symbol set can be swapped — or pointed at
/// custom marker artwork later — without touching the model.
struct ThemeIcon: Identifiable, Sendable {
    let id: String          // token stored in Theme.iconToken
    let systemName: String  // SF Symbol name
    let displayName: String
}

enum ThemeIcons {
    static let `default` = "star"

    static let all: [ThemeIcon] = [
        ThemeIcon(id: "meds",     systemName: "pills.fill",           displayName: "Meds"),
        ThemeIcon(id: "leave",    systemName: "door.left.hand.open",  displayName: "Leave"),
        ThemeIcon(id: "morning",  systemName: "sun.max.fill",         displayName: "Morning"),
        ThemeIcon(id: "night",    systemName: "moon.fill",            displayName: "Night"),
        ThemeIcon(id: "food",     systemName: "fork.knife",           displayName: "Food"),
        ThemeIcon(id: "work",     systemName: "briefcase.fill",       displayName: "Work"),
        ThemeIcon(id: "clean",    systemName: "sparkles",             displayName: "Clean"),
        ThemeIcon(id: "exercise", systemName: "figure.run",           displayName: "Exercise"),
        ThemeIcon(id: "water",    systemName: "drop.fill",            displayName: "Water"),
        ThemeIcon(id: "star",     systemName: "star.fill",            displayName: "Star"),
    ]

    /// SF Symbol for a token, falling back to a neutral list glyph for unknown tokens.
    static func symbolName(for token: String) -> String {
        all.first { $0.id == token }?.systemName ?? "list.bullet"
    }
}
