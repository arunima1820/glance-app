import SwiftUI
import SwiftData

// MARK: - ContentView
/// Root view: decides whether to show the onboarding intro or the Themes home screen.
struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        if hasSeenOnboarding {
            ThemesView()
        } else {
            OnboardingView(onDismiss: { hasSeenOnboarding = true })
        }
    }
}
