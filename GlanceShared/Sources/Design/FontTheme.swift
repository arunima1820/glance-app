import SwiftUI

// MARK: - FontRole
/// Semantic text roles. Views ask for a role, not a specific font/size,
/// so the whole typographic feel can be swapped in one place.
enum FontRole: Sendable, CaseIterable {
    case appTitle      // the "Glance" wordmark
    case screenTitle   // main screen headings (Food, Settings, onboarding)
    case listTitle     // a list's own header on its Steps screen
    case rowLead       // the bold lead word of a list row
    case rowBody       // list row detail text (~9pt baseline)
    case cardTitle     // theme card (tile) name
    case caption       // sublines, hints
    case button        // primary action label
    case widgetTitle   // widget theme name / chip label
    case widgetBody    // widget step text: deliberately small and tight
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
    case marker   // default: Cabin Sketch hand lettering, SF Pro Rounded body
    case system   // alternate: all system, rounded
}

// MARK: - FontThemes registry
enum FontThemes {
    static let `default`: FontThemeID = .marker

    /// Resolves a theme by id.
    /// - Parameter id: the font theme to resolve.
    static func theme(_ id: FontThemeID) -> FontTheme {
        switch id {
        case .marker: return MarkerFontTheme()
        case .system: return SystemFontTheme()
        }
    }
}

// MARK: - BundledFont
/// Every font file shipped in the app and the widget (`GlanceShared/Fonts`, listed in both
/// Info.plists under `UIAppFonts`). Raw value = PostScript name; file = raw value + ".ttf".
///
/// To swap a face: drop the .ttf into GlanceShared/Fonts, add a case here, add the file to
/// both Info.plists, then point a role at it in `MarkerFontTheme`. FontThemeTests fail if a
/// case isn't registered in the app or the widget.
enum BundledFont: String, CaseIterable, Sendable {
    case cabinSketchBold = "CabinSketch-Bold"

    /// The name iOS registers the face under (what `Font.custom` needs).
    var postScriptName: String { rawValue }
    /// The bundled file, as listed in `UIAppFonts`.
    var fileName: String { rawValue + ".ttf" }
}

// MARK: - MarkerFontTheme (default)
/// The hand-drawn look: Cabin Sketch for every hand-lettered role (wordmark, titles, list
/// headers, tiles, buttons, widget titles); SF Pro Rounded for everything you read.
/// The three `…Face` constants are the only places to change which face does what; they
/// share one face today but can diverge for an experiment.
struct MarkerFontTheme: FontTheme {
    let id: FontThemeID = .marker
    let displayName = "Marker"

    /// "Glance" and main screen titles.
    static let headlineFace: BundledFont = .cabinSketchBold
    /// A list's header on its Steps screen.
    static let listTitleFace: BundledFont = .cabinSketchBold
    /// List tiles, widget titles, buttons.
    static let tileFace: BundledFont = .cabinSketchBold

    /// Font for a role.
    /// - Parameter role: the semantic text role.
    func font(_ role: FontRole) -> Font {
        switch role {
        case .appTitle:    return custom(Self.headlineFace, 30, relativeTo: .largeTitle)
        case .screenTitle: return custom(Self.headlineFace, 16, relativeTo: .callout)
        case .listTitle:   return custom(Self.listTitleFace, 16, relativeTo: .callout)   // same size as row text
        case .cardTitle:   return custom(Self.tileFace, 16, relativeTo: .callout)        // same size as row text
        case .button:      return custom(Self.tileFace, 19, relativeTo: .headline)
        case .widgetTitle: return custom(Self.tileFace, 13, relativeTo: .caption)
        default:           return SystemFontTheme().font(role)   // body roles are shared
        }
    }

    /// A bundled face that scales with Dynamic Type; iOS falls back to system if missing.
    private func custom(_ face: BundledFont, _ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(face.postScriptName, size: size, relativeTo: style)
    }
}

// MARK: - SystemFontTheme (alternate, no bundled font)
/// A fully native fallback — useful for an A/B arm or if the bundled faces are unavailable.
struct SystemFontTheme: FontTheme {
    let id: FontThemeID = .system
    let displayName = "System"

    /// Font for a role.
    /// - Parameter role: the semantic text role.
    func font(_ role: FontRole) -> Font {
        switch role {
        case .appTitle:    return .system(.largeTitle, design: .rounded).weight(.heavy)
        case .screenTitle: return .system(.callout, design: .rounded).weight(.bold)
        case .listTitle:   return .system(.callout, design: .rounded).weight(.bold)
        case .rowLead:     return .system(.callout, design: .rounded).weight(.semibold)
        case .rowBody:     return .system(.callout, design: .rounded)
        case .cardTitle:   return .system(.callout, design: .rounded).weight(.bold)
        case .caption:     return .system(.caption, design: .rounded)
        case .button:      return .system(.headline, design: .rounded)
        case .widgetTitle: return .system(.caption, design: .rounded).weight(.bold)
        case .widgetBody:  return .system(size: 11, design: .rounded)   // fixed: widgets are glanced, not read
        }
    }
}
