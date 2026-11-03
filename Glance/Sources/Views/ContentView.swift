import Combine
import SwiftUI
import SwiftData

// MARK: - ContentView
/// Root view: onboarding on first launch, then the tab bar (Lists · Food · Settings).
/// Also applies the user's appearance + font-theme choices app-wide.
struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("glance.appearance") private var appearance: AppAppearance = .system
    @AppStorage(WidgetDataBridge.fontThemeKey, store: WidgetDataBridge.defaults) private var fontThemeID: FontThemeID = FontThemes.default
    @EnvironmentObject private var design: DesignConfig

    var body: some View {
        Group {
            if hasSeenOnboarding {
                RootTabView()
            } else {
                OnboardingView(onDismiss: { hasSeenOnboarding = true })
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .onAppear { design.fontThemeID = fontThemeID }
        .onChange(of: fontThemeID) { _, newValue in
            design.fontThemeID = newValue
            WidgetDataBridge.reloadWidgets()   // widget titles follow the Settings choice
        }
    }
}

// MARK: - RootTabView
/// The standard bottom tabs. Food is gated by `FeatureFlags.groceriesTabVisible`.
/// Widget taps arrive as `glance://` links: they switch to Lists and open that list.
struct RootTabView: View {
    @EnvironmentObject private var design: DesignConfig
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var tab = RootTab.lists
    @State private var linkedThemeID: UUID?
    @State private var now = Date()

    var body: some View {
        TabView(selection: $tab) {
            ThemesView(linkedThemeID: $linkedThemeID)
                .tabItem { Label("Lists", systemImage: "list.bullet.rectangle") }
                .tag(RootTab.lists)
            if design.flags.groceriesTabVisible {
                FoodPlaceholderView()
                    .tabItem { Label("Food", systemImage: "refrigerator") }
                    .tag(RootTab.food)
            }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(RootTab.settings)
        }
        .tint(palette.marker)
        .environment(\.glanceNow, now)
        .onOpenURL(perform: open)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDay() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            refreshDay()
        }
    }

    /// New day or back from the background: re-judge ticks and rewrite the widget snapshot.
    private func refreshDay() {
        now = Date()
        WidgetDataBridge.refresh(from: modelContext)
    }

    /// Routes a deep link: any glance:// URL shows Lists; a theme link also opens that list.
    /// - Parameter url: the incoming URL.
    private func open(_ url: URL) {
        guard url.scheme == GlanceLink.scheme else { return }
        tab = .lists
        linkedThemeID = GlanceLink.themeID(from: url)
    }
}

/// The bottom tabs.
enum RootTab: Hashable {
    case lists, food, settings
}

// MARK: - FoodPlaceholderView
/// Stand-in for the groceries tracker (milestones 3–4).
struct FoodPlaceholderView: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "refrigerator")
                    .font(.system(size: 44))
                    .foregroundStyle(palette.avocado)
                    .accessibilityHidden(true)
                Text("Food is coming soon")
                    .font(fonts.font(.cardTitle))
                    .foregroundStyle(palette.ink)
                Text("Track what's in the fridge and when to use it up.")
                    .font(fonts.font(.rowBody))
                    .foregroundStyle(palette.ink2)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .paperBackground(palette)
            .paperBars(palette)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Food").font(fonts.font(.screenTitle)).foregroundStyle(palette.ink)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
