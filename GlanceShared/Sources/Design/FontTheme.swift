import SwiftUI

// MARK: - FontRole
/// Semantic text roles. Views ask for a role, not a specific font/size,
/// so the whole typographic feel can be swapped in one place.
enum FontRole: Sendable {
    case appTitle      // the "Glance" wordmark
    case screenTitle   // a theme / screen heading
    case rowLead       // the bold lead word of a list row
    case rowBody       // list row detail text (~9pt baseline)
    case cardTitle     // theme card name
    case caption       // sublines, hints
    case button        // primary action label
}

// MARK: - FontTheme
/// Maps roles to concrete fonts. Conformers are swappable via `FontThemeID`.
/// All sizes are expressed as Dynamic Type `relativeTo:` styles so they scale.
protocol FontTheme: Sendable {
    var id: FontThemeID { get }
    var displayName: String { get }
    func font(_ role: FontRole) -> Font
}

enum FontThemeID: String, CaseIterable, Sendable {
    case marker   // default: Permanent Marker titles + SF Pro Rounded body
    case system   // alternate: all system, rounded
}

// MARK: - FontThemes registry
enum FontThemes {
    static let `default`: FontThemeID = .marker

    static func theme(_ id: FontThemeID) -> FontTheme {
        switch id {
        case .marker: return MarkerFontTheme()
        case .system: return SystemFontTheme()
        }
    }
}

// MARK: - MarkerFontTheme (default)
/// Permanent Marker for the wordmark & screen titles; SF Pro Rounded for everything read.
/// `markerFamily` is the single point to change the title face.
struct MarkerFontTheme: FontTheme {
    let id: FontThemeID = .marker
    let displayName = "Marker"

    /// The bundled title face. Swap this string (and the bundled file) to try another.
    static let markerFamily = "PermanentMarker-Regular"

    func font(_ role: FontRole) -> Font {
        switch role {
        case .appTitle:    return marker(28, relativeTo: .largeTitle)
        case .screenTitle: return marker(22, relativeTo: .title)
        case .rowLead:     return .system(.callout, design: .rounded).weight(.semibold)
        case .rowBody:     return .system(.callout, design: .rounded)        // ~9pt baseline, scales up
        case .cardTitle:   return .system(.subheadline, design: .rounded).weight(.bold)
        case .caption:     return .system(.caption, design: .rounded)
        case .button:      return marker(18, relativeTo: .headline)
        }
    }

    /// Custom marker font with a system fallback if the face is missing.
    private func marker(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(Self.markerFamily, size: size, relativeTo: style)
    }
}

// MARK: - SystemFontTheme (alternate, no bundled font)
/// A fully native fallback — useful for an A/B arm or if the marker face is unavailable.
struct SystemFontTheme: FontTheme {
    let id: FontThemeID = .system
    let displayName = "System"

    func font(_ role: FontRole) -> Font {
        switch role {
        case .appTitle:    return .system(.largeTitle, design: .rounded).weight(.heavy)
        case .screenTitle: return .system(.title, design: .rounded).weight(.bold)
        case .rowLead:     return .system(.callout, design: .rounded).weight(.semibold)
        case .rowBody:     return .system(.callout, design: .rounded)
        case .cardTitle:   return .system(.subheadline, design: .rounded).weight(.bold)
        case .caption:     return .system(.caption, design: .rounded)
        case .button:      return .system(.headline, design: .rounded)
        }
    }
}
