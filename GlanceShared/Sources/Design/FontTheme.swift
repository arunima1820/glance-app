import SwiftUI

// MARK: - FontRole
/// Semantic text roles. Views ask for a role, not a specific font/size,
/// so the whole typographic feel can be swapped in one place.
enum FontRole: Sendable, CaseIterable {
    case appTitle      // the "Glance" wordmark
    case screenTitle   // main screen headings (Food, Settings, onboarding)
    case listTitle     // a list's own header on its Steps screen
    case rowLead       // the bold lead word of a list row
    case rowBody       // list row detail text (callout, Dynamic Type)
    case cardTitle     // theme card (tile) name
    case caption       // sublines, hints
    case button        // primary action label
    case widgetTitle   // widget list / section name
    case widgetBody    // small widget text: deliberately small and tight
    case widgetBodyRoomy   // medium / large widget text: the size of app names on the home screen
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
        default:           return SystemFontTheme.native(role, design: .rounded)   // body roles: SF Pro Rounded
        }
    }

    /// A bundled face that scales with Dynamic Type; iOS falls back to system if missing.
    private func custom(_ face: BundledFont, _ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(face.postScriptName, size: size, relativeTo: style)
    }
}

// MARK: - SystemFontTheme (alternate, no bundled font)
/// "System" in Settings: every role in Apple's own San Francisco face (SF Pro), standard iOS
/// text styles and weights, no hand lettering at all. Also supplies the body roles to the
/// Marker theme, which reads them in SF Pro Rounded.
struct SystemFontTheme: FontTheme {
    let id: FontThemeID = .system
    let displayName = "System"

    /// Font for a role.
    /// - Parameter role: the semantic text role.
    func font(_ role: FontRole) -> Font {
        Self.native(role, design: .default)
    }

    /// The native font for a role in a given system design (default or rounded).
    /// - Parameters:
    ///   - role: the semantic text role.
    ///   - design: `.default` (SF Pro) or `.rounded` (SF Pro Rounded).
    static func native(_ role: FontRole, design: Font.Design) -> Font {
        switch role {
        case .appTitle:        return .system(.largeTitle, design: design).weight(.bold)
        case .screenTitle:     return .system(.headline, design: design)
        case .listTitle:       return .system(.callout, design: design).weight(.semibold)
        case .rowLead:         return .system(.callout, design: design).weight(.semibold)
        case .rowBody:         return .system(.callout, design: design)
        case .cardTitle:       return .system(.callout, design: design).weight(.semibold)
        case .caption:         return .system(.caption, design: design)
        case .button:          return .system(.headline, design: design)
        case .widgetTitle:     return .system(.caption, design: design).weight(.semibold)
        case .widgetBody:      return .system(size: 11, design: design)   // fixed: widgets are glanced, not read
        case .widgetBodyRoomy: return .system(size: 12, design: design)   // home-screen app-name size
        }
    }
}
