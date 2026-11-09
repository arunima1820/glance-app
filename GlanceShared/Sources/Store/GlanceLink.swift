import Foundation

// MARK: - GlanceLink
/// The app's deep links (used by widget taps):
/// `glance://theme/<uuid>` opens a list, `glance://food/<uuid>` opens a food,
/// `glance://food` opens the Food tab, and `glance://open` just opens the app.
enum GlanceLink {
    static let scheme = "glance"
    /// Opens the app without a specific screen.
    static let open = URL(string: "glance://open")!
    /// Opens the Food tab.
    static let foodTab = URL(string: "glance://food")!

    /// Where a link should take the user.
    enum Route: Equatable {
        case open
        case theme(UUID)
        case foodTab
        case food(UUID)
    }

    /// URL that opens a list.
    /// - Parameter id: the theme's id.
    static func theme(_ id: UUID) -> URL {
        URL(string: "\(scheme)://theme/\(id.uuidString)")!
    }

    /// URL that opens one food.
    /// - Parameter id: the food's id.
    static func food(_ id: UUID) -> URL {
        URL(string: "\(scheme)://food/\(id.uuidString)")!
    }

    /// Parses a theme id out of a `glance://theme/<uuid>` URL.
    /// - Parameter url: an incoming URL.
    /// - Returns: the id, or nil for any other / malformed URL.
    static func themeID(from url: URL) -> UUID? {
        guard url.scheme == scheme, url.host() == "theme" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }

    /// Reads any glance:// URL. A malformed id falls back to the tab it belongs to.
    /// - Parameter url: an incoming URL.
    /// - Returns: the route, or nil when the URL isn't one of ours.
    static func route(from url: URL) -> Route? {
        guard url.scheme == scheme else { return nil }
        let id = UUID(uuidString: url.lastPathComponent)
        switch url.host() {
        case "theme": return id.map(Route.theme) ?? .open
        case "food": return id.map(Route.food) ?? .foodTab
        default: return .open
        }
    }
}
