import SwiftUI

// MARK: - GlanceWatchApp (stub — planned for a later version)
/// The Apple Watch app and complication are explicitly planned for v2.
/// This stub keeps the target in the project so the architecture is in place,
/// but it ships nothing in v1.
///
/// When ready:
/// - Add a real WKApplicationDelegate (or use @main SwiftUI lifecycle)
/// - Add WatchConnectivity session to receive quick updates from the iPhone
/// - Build a simple list view matching StepsView
/// - Add a WidgetKit complication showing the current theme name / first step

@main
struct GlanceWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchPlaceholderView()
        }
    }
}

struct WatchPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "applewatch")
                .font(.largeTitle)
            Text("Watch app coming soon")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }
}
