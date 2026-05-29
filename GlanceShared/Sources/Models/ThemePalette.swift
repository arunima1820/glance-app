import SwiftUI

// MARK: - ThemePalette
/// Curated soft pastel accent colors.
/// Design rule: never red/green or red/pink pairings for anything meaningful.
/// Color is always paired with icon + name — never relied upon alone.
struct ThemePalette {
    struct Entry: Identifiable {
        let id: String        // token used in Theme.colorToken
        let light: Color
        let dark: Color
        let displayName: String
    }

    static let all: [Entry] = [
        Entry(id: "sage",       light: Color(hex: "#B8D4C0"), dark: Color(hex: "#3A5442"), displayName: "Sage"),
        Entry(id: "lavender",   light: Color(hex: "#C9C0D8"), dark: Color(hex: "#4A3F5C"), displayName: "Lavender"),
        Entry(id: "sky",        light: Color(hex: "#B3CCE0"), dark: Color(hex: "#2D4A5E"), displayName: "Sky"),
        Entry(id: "peach",      light: Color(hex: "#F0C8B0"), dark: Color(hex: "#6B3E28"), displayName: "Peach"),
        Entry(id: "butter",     light: Color(hex: "#EAE0A8"), dark: Color(hex: "#5C500A"), displayName: "Butter"),
        Entry(id: "rose",       light: Color(hex: "#E8BCC8"), dark: Color(hex: "#6B2D40"), displayName: "Rose"),
        Entry(id: "slate",      light: Color(hex: "#C0C8D4"), dark: Color(hex: "#3A4252"), displayName: "Slate"),
        Entry(id: "clay",       light: Color(hex: "#D8C0B4"), dark: Color(hex: "#5C3A2D"), displayName: "Clay"),
    ]

    static func entry(for token: String) -> Entry {
        all.first { $0.id == token } ?? all[0]
    }
}

// MARK: - Color hex init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
