import SwiftUI
import SwiftData

// MARK: - GlanceApp
/// The app: one shared SwiftData container, styled by the design config.
/// In Debug simulator builds, launching with GLANCE_TEST_DATA loads a test data file
/// (TestDataLoader).
@main
struct GlanceApp: App {
    /// The store. A damaged store no longer crashes the app: it's set aside and the user is
    /// told once (RootTabView reads `StorageKeys.storeNotice`).
    private let container: ModelContainer = {
        let opened = GlanceStore.makeContainerRecovering()
        if opened.outcome != .opened {
            UserDefaults.standard.set(opened.outcome == .reset ? "reset" : "temporary", forKey: StorageKeys.storeNotice)
        }
        return opened.container
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .glanceStyled()          // injects resolved palette + fonts + shared config
                .modelContainer(container)
                #if DEBUG && targetEnvironment(simulator)
                .task { TestDataLoader.loadIfRequested(into: container.mainContext) }
                #endif
        }
    }
}
