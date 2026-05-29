import WidgetKit
import SwiftUI

// MARK: - Widget bundle
/// Registers all widget kinds: home-screen (small/medium/large) and lock-screen.
@main
struct GlanceWidgetBundle: WidgetBundle {
    var body: some Widget {
        GlanceHomeWidget()
        GlanceLockScreenWidget()
    }
}
