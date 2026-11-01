import SwiftUI

// MARK: - CategoryPalette
/// Clear, distinguishable accent colors for user-named categories (e.g. "red" → "Urgent").
/// Broader and more saturated than ThemePalette (which is soft routine accents), because
/// categories are the app's main color-coding axis. Each color is always shown with the
/// category's NAME, so color is never the sole signal (accessibility rule).
struct CategoryPalette {
    struct Entry: Identifiable {
        let id: String        // token stored in Category.colorToken
        let light: Color
        let dark: Color
        let displayName: String
    }

    static let all: [Entry] = [
        Entry(id: "red",    light: Color(hex: "#E06C6C"), dark: Color(hex: "#5C2626"), displayName: "Red"),
        Entry(id: "orange", light: Color(hex: "#E3965A"), dark: Color(hex: "#5C3415"), displayName: "Orange"),
        Entry(id: "amber",  light: Color(hex: "#E0BE5A"), dark: Color(hex: "#5C4710"), displayName: "Amber"),
        Entry(id: "green",  light: Color(hex: "#7FBF7F"), dark: Color(hex: "#244A24"), displayName: "Green"),
        Entry(id: "teal",   light: Color(hex: "#5FB8B0"), dark: Color(hex: "#174A45"), displayName: "Teal"),
        Entry(id: "blue",   light: Color(hex: "#6FA6DE"), dark: Color(hex: "#1D3E5C"), displayName: "Blue"),
        Entry(id: "indigo", light: Color(hex: "#8486D4"), dark: Color(hex: "#262759"), displayName: "Indigo"),
        Entry(id: "purple", light: Color(hex: "#A98AD4"), dark: Color(hex: "#352459"), displayName: "Purple"),
        Entry(id: "pink",   light: Color(hex: "#DE92BE"), dark: Color(hex: "#59243F"), displayName: "Pink"),
        Entry(id: "brown",  light: Color(hex: "#B8977A"), dark: Color(hex: "#452F20"), displayName: "Brown"),
        Entry(id: "gray",   light: Color(hex: "#A6AAB2"), dark: Color(hex: "#33373F"), displayName: "Gray"),
    ]

    /// Looks up a palette entry by token, falling back to the first entry for unknown tokens.
    static func entry(for token: String) -> Entry {
        all.first { $0.id == token } ?? all[0]
    }
}
