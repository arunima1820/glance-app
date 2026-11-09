import Combine
import SwiftUI
import SwiftData

// MARK: - ContentView
/// Root view: onboarding on first launch, then the tab bar (Lists · Food · Settings).
/// Also applies the user's appearance + font-theme choices app-wide.
struct ContentView: View {
    @AppStorage(StorageKeys.hasSeenOnboarding) private var hasSeenOnboarding = false
    @AppStorage(StorageKeys.appearance) private var appearance: AppAppearance = .system
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
/// Widget taps arrive as `glance://` links: they switch to the right tab and open that list
/// or food.
struct RootTabView: View {
    @EnvironmentObject private var design: DesignConfig
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    /// Reopens on the tab you left (stored, so it survives closing the app).
    @AppStorage(StorageKeys.lastTab) private var tab: RootTab = .lists
    @State private var linkedThemeID: UUID?
    @State private var linkedFoodID: UUID?
    @State private var now = Date()
    @AppStorage(StorageKeys.storeNotice) private var storeNotice = ""

    var body: some View {
        TabView(selection: $tab) {
            ThemesView(linkedThemeID: $linkedThemeID)
                .tabItem { Label("Lists", systemImage: "list.bullet.rectangle") }
                .tag(RootTab.lists)
            if design.flags.groceriesTabVisible {
                FoodView(linkedFoodID: $linkedFoodID)
                    .tabItem { Label("Food", systemImage: "refrigerator") }
                    .tag(RootTab.food)
            }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(RootTab.settings)
        }
        .tint(palette.markerDeep)   // small text (tab labels, Cancel) needs 4.5:1
        .environment(\.glanceNow, now)
        .alert(storeNoticeTitle, isPresented: showingStoreNotice) {
            Button("OK") { storeNotice = "" }
        } message: {
            Text(storeNoticeMessage)
        }
        .onOpenURL(perform: open)
        .onAppear {
            if tab == .food && !design.flags.groceriesTabVisible { tab = .lists }   // Food switched off
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDay() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            refreshDay()
        }
    }

    /// Shows the store notice once, if the store had to be reset or run in memory.
    private var showingStoreNotice: Binding<Bool> {
        Binding(get: { !storeNotice.isEmpty }, set: { if !$0 { storeNotice = "" } })
    }

    private var storeNoticeTitle: String {
        storeNotice == "reset" ? "Glance started fresh" : "Changes won't be kept right now"
    }

    private var storeNoticeMessage: String {
        storeNotice == "reset"
            ? "Your saved lists and food couldn't be opened, so Glance started a new, empty board. The old file is kept on your iPhone."
            : "Glance couldn't open your saved lists. Close and reopen the app; anything added now won't be saved."
    }

    /// New day or back from the background: re-judge ticks and expiry, rewrite both widget
    /// snapshots.
    private func refreshDay() {
        now = Date()
        WidgetDataBridge.refresh(from: modelContext)
        WidgetDataBridge.refreshFood(from: modelContext)
    }

    /// Routes a deep link to its tab, and opens the list or food it names.
    /// - Parameter url: the incoming URL.
    private func open(_ url: URL) {
        guard let route = GlanceLink.route(from: url) else { return }
        switch route {
        case .open:
            tab = .lists
        case .theme(let id):
            tab = .lists
            linkedThemeID = id
        case .foodTab:
            tab = design.flags.groceriesTabVisible ? .food : .lists
        case .food(let id):
            guard design.flags.groceriesTabVisible else { tab = .lists; return }
            tab = .food
            linkedFoodID = id
        }
    }
}

/// The bottom tabs. Raw values are stored (`StorageKeys.lastTab`), so don't rename them.
enum RootTab: String, Hashable, CaseIterable {
    case lists, food, settings
}
