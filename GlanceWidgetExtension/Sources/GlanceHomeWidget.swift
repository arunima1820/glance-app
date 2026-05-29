import WidgetKit
import SwiftUI
import AppIntents

// MARK: - GlanceHomeWidget
/// Home-screen widget in three sizes (small, medium, large).
/// Medium + large: theme chips across the top; steps of selected theme below.
/// Small: one theme's steps, tapping opens the app.
///
/// Tap-to-switch chips use AppIntents (iOS 17+) — the key interactive widget feature.
struct GlanceHomeWidget: Widget {
    let kind = "GlanceHomeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectThemeIntent.self,
            provider: GlanceTimelineProvider()
        ) { entry in
            GlanceHomeWidgetView(entry: entry)
                .containerBackground(GlanceWidgetColors.background, for: .widget)
        }
        .configurationDisplayName("Glance")
        .description("See your tiny list at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - AppIntent for selecting a theme inside the widget

struct SelectThemeIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Select Theme"
    static let description = IntentDescription("Choose which theme's steps to display.")

    @Parameter(title: "Theme ID")
    var selectedThemeID: String?

    init() {}
    init(selectedThemeID: String?) {
        self.selectedThemeID = selectedThemeID
    }

    func perform() async throws -> some IntentResult {
        // The intent itself just carries the selected ID back as widget configuration.
        return .result()
    }
}

// MARK: - Timeline provider

struct GlanceEntry: TimelineEntry {
    let date: Date
    let themes: [ThemeSnapshot]
    let selectedThemeID: String?

    var selectedTheme: ThemeSnapshot? {
        if let id = selectedThemeID, let match = themes.first(where: { $0.id.uuidString == id }) {
            return match
        }
        return themes.first
    }
}

struct GlanceTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = GlanceEntry
    typealias Intent = SelectThemeIntent

    func placeholder(in context: Context) -> GlanceEntry {
        GlanceEntry(date: Date(), themes: placeholderThemes, selectedThemeID: nil)
    }

    func snapshot(for configuration: SelectThemeIntent, in context: Context) async -> GlanceEntry {
        let themes = Self.loadThemes()
        return GlanceEntry(date: Date(), themes: themes, selectedThemeID: configuration.selectedThemeID)
    }

    func timeline(for configuration: SelectThemeIntent, in context: Context) async -> Timeline<GlanceEntry> {
        let themes = Self.loadThemes()
        let entry = GlanceEntry(date: Date(), themes: themes, selectedThemeID: configuration.selectedThemeID)
        // No time-based refresh needed — the app pushes updates via WidgetCenter.
        return Timeline(entries: [entry], policy: .never)
    }

    /// Reads live data from the App Group bridge; falls back to placeholder
    /// themes when running in the simulator without a real App Group (dev mode).
    private static func loadThemes() -> [ThemeSnapshot] {
        let live = WidgetDataBridge.readSnapshot()
        return live.isEmpty ? GlanceTimelineProvider().placeholderThemes : live
    }

    var placeholderThemes: [ThemeSnapshot] {
        [
            ThemeSnapshot(
                id: UUID(),
                name: "Take meds",
                colorToken: "sage",
                iconEmoji: "💊",
                steps: [
                    StepSnapshot(id: UUID(), text: "Get water", iconEmoji: "💧"),
                    StepSnapshot(id: UUID(), text: "Take tablets", iconEmoji: "💊"),
                ]
            ),
            ThemeSnapshot(
                id: UUID(),
                name: "Leave the house",
                colorToken: "sky",
                iconEmoji: "🚪",
                steps: [
                    StepSnapshot(id: UUID(), text: "Grab keys", iconEmoji: "🔑"),
                    StepSnapshot(id: UUID(), text: "Phone charged", iconEmoji: "🔋"),
                    StepSnapshot(id: UUID(), text: "Lock the door", iconEmoji: nil),
                ]
            ),
            ThemeSnapshot(
                id: UUID(),
                name: "Morning",
                colorToken: "butter",
                iconEmoji: "☀️",
                steps: [
                    StepSnapshot(id: UUID(), text: "Drink water", iconEmoji: "💧"),
                    StepSnapshot(id: UUID(), text: "Take meds", iconEmoji: "💊"),
                    StepSnapshot(id: UUID(), text: "Get dressed", iconEmoji: nil),
                ]
            ),
        ]
    }
}

// MARK: - Widget views

struct GlanceHomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GlanceEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium, .systemLarge:
            MediumLargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: Small widget
struct SmallWidgetView: View {
    let entry: GlanceEntry

    var body: some View {
        Group {
            if let theme = entry.selectedTheme {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(theme.iconEmoji)
                            .font(.system(size: 20))
                        Text(theme.name)
                            .font(.headline)
                            .lineLimit(1)
                            .foregroundStyle(GlanceWidgetColors.primaryText)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(theme.iconEmoji) \(theme.name)")

                    ForEach(theme.steps.prefix(4)) { step in
                        Text(step.text)
                            .font(.subheadline)
                            .foregroundStyle(GlanceWidgetColors.primaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Text("No themes yet.\nOpen Glance to add one.")
                    .font(.caption)
                    .foregroundStyle(GlanceWidgetColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .widgetURL(URL(string: "glance://open"))
    }
}

// MARK: Medium / Large widget
struct MediumLargeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GlanceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Theme chip row
            if entry.themes.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entry.themes) { theme in
                            Button(intent: SelectThemeIntent(selectedThemeID: theme.id.uuidString)) {
                                ThemeChipView(
                                    theme: theme,
                                    isSelected: entry.selectedTheme?.id == theme.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 40)
                .accessibilityLabel("Themes")
            }

            // Steps for selected theme
            if let theme = entry.selectedTheme {
                let maxSteps = family == .systemLarge ? 8 : 4
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(theme.steps.prefix(maxSteps)) { step in
                        HStack(spacing: 8) {
                            if let icon = step.iconEmoji {
                                Text(icon).font(.system(size: 16))
                                    .accessibilityHidden(true)
                            }
                            Text(step.text)
                                .font(.subheadline)
                                .foregroundStyle(GlanceWidgetColors.primaryText)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetURL(URL(string: "glance://theme/\(theme.id.uuidString)"))
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

// MARK: Theme chip
struct ThemeChipView: View {
    let theme: ThemeSnapshot
    let isSelected: Bool

    private var palette: ThemePalette.Entry { ThemePalette.entry(for: theme.colorToken) }

    var body: some View {
        HStack(spacing: 4) {
            Text(theme.iconEmoji).font(.system(size: 14))
                .accessibilityHidden(true)
            Text(theme.name)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? palette.light : GlanceWidgetColors.chipBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isSelected ? palette.light.opacity(0) : GlanceWidgetColors.chipBorder, lineWidth: 1)
        )
        .foregroundStyle(GlanceWidgetColors.primaryText)
        .accessibilityLabel("\(theme.name)\(isSelected ? ", selected" : "")")
    }
}

// MARK: - Widget colors (lightweight, no asset catalog dependency)
enum GlanceWidgetColors {
    static let background    = Color("GlanceBackground")
    static let primaryText   = Color("GlancePrimaryText")
    static let secondaryText = Color("GlanceSecondaryText")
    static let chipBackground = Color("GlanceSurface")
    static let chipBorder     = Color.gray.opacity(0.2)
}
