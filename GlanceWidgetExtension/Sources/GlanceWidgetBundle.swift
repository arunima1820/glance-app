import WidgetKit
import SwiftUI

// MARK: - Widget bundle
/// Registers all widget kinds: Glance (lists; small/medium/large), Glance Food (small/medium),
/// and the lock-screen widget.
@main
struct GlanceWidgetBundle: WidgetBundle {
    var body: some Widget {
        GlanceHomeWidget()
        GlanceFoodWidget()
        GlanceLockScreenWidget()
    }
}
