import SwiftUI
import SwiftData

@main
struct GlanceApp: App {
    private let container: ModelContainer = {
        do {
            return try GlanceStore.makeContainer()
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
