import AppIntents
import SwiftUI
import WidgetKit

// MARK: - GlanceFoodWidget
/// "Glance Food": the food to use up soon, small (5) or medium (8, two columns). Each widget
/// has its own look-ahead (Edit Widget). Canned food shows only once it's that close. Taps
/// open the Food tab.
struct GlanceFoodWidget: Widget {
    let kind = "GlanceFoodWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: FoodWidgetIntent.self, provider: FoodTimelineProvider()) { entry in
            FoodWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Glance Food")
        .description("The food to use up soon.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - LookAhead
/// How far ahead a Food widget looks (Edit Widget → Look ahead).
enum LookAhead: String, CaseIterable, AppEnum {
    case threeDays, week, twoWeeks, threeWeeks, month

    /// The setting's name in Edit Widget.
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Look ahead" }

    /// Each choice's wording in Edit Widget.
    static var caseDisplayRepresentations: [LookAhead: DisplayRepresentation] {
        [.threeDays: "3 days", .week: "7 days", .twoWeeks: "14 days", .threeWeeks: "3 weeks", .month: "1 month"]
    }

    /// The window in days.
    var days: Int {
        switch self {
        case .threeDays: return 3
        case .week: return 7
        case .twoWeeks: return 14
        case .threeWeeks: return 21
        case .month: return 31
        }
    }
}

// MARK: - FoodWidgetIntent
/// Each Food widget's own settings.
struct FoodWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Glance Food"
    static let description = IntentDescription("Shows the food to use up soon.")

    @Parameter(title: "Look ahead", default: .twoWeeks)
    var lookAhead: LookAhead

    @Parameter(title: "Show expired", default: true)
    var showExpired: Bool

    init() {}

    /// Nothing to do: these are settings only; the timeline reads them.
    func perform() async throws -> some IntentResult {
        .result()   // settings only; the timeline reads them
    }
}

// MARK: - FoodEntry
/// One moment of a Food widget: the foods to show, in order.
struct FoodEntry: TimelineEntry {
    let date: Date
    let items: [FoodSnapshot]
}

// MARK: - FoodTimelineProvider
/// Builds Food widget entries from the App Group food snapshot.
struct FoodTimelineProvider: AppIntentTimelineProvider {
    /// Example foods while the widget loads.
    func placeholder(in context: Context) -> FoodEntry {
        FoodEntry(date: Date(), items: Self.samples(now: Date()))
    }

    /// The entry for right now (examples in the gallery when there's no food yet).
    func snapshot(for configuration: FoodWidgetIntent, in context: Context) async -> FoodEntry {
        let entry = Self.makeEntry(configuration, at: Date())
        // The widget gallery shows examples when there's no food yet.
        return context.isPreview && entry.items.isEmpty ? placeholder(in: context) : entry
    }

    /// Now, plus each of the next 8 midnights, so "today" / "2 days" stay right without the app.
    func timeline(for configuration: FoodWidgetIntent, in context: Context) async -> Timeline<FoodEntry> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let midnights = (1...8).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let entries = ([Date()] + midnights).map { Self.makeEntry(configuration, at: $0) }
        return Timeline(entries: entries, policy: .atEnd)
    }

    /// The foods due within this widget's window at `date`.
    private static func makeEntry(_ configuration: FoodWidgetIntent, at date: Date) -> FoodEntry {
        let items = FoodQuery.useSoon(WidgetDataBridge.readFood(), now: date,
                                      lookAheadDays: configuration.lookAhead.days,
                                      includeExpired: configuration.showExpired)
        return FoodEntry(date: date, items: items)
    }

    /// Example foods for the gallery.
    private static func samples(now: Date) -> [FoodSnapshot] {
        let names = ["Eggs", "Shrimp", "Fried rice", "Oat milk", "Spinach", "Yogurt", "Bread", "Kimchi"]
        return names.enumerated().map { index, name in
            FoodSnapshot(id: UUID(), name: name, useBy: Calendar.current.date(byAdding: .day, value: index, to: now))
        }
    }
}

// MARK: - FoodWidgetView
/// Small: title + 5 foods. Medium: title + 8 foods in two columns. Empty: the calm line.
struct FoodWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: FoodEntry

    var body: some View {
        let style = WidgetStyle(scheme)
        Group {
            if entry.items.isEmpty {
                WidgetFoodCalm(style: style)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    WidgetFoodTitle(style: style)
                    columns(style)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .widgetURL(GlanceLink.foodTab)
    }

    /// One column on small; two side by side on medium.
    @ViewBuilder private func columns(_ style: WidgetStyle) -> some View {
        if family == .systemMedium {
            let shown = Array(entry.items.prefix(8))
            HStack(alignment: .top, spacing: 10) {
                WidgetFoodList(items: Array(shown.prefix(4)), date: entry.date, style: style)
                WidgetVerticalDivider(color: style.palette.ink2.opacity(0.4))
                WidgetFoodList(items: Array(shown.dropFirst(4)), date: entry.date, style: style)
            }
        } else {
            WidgetFoodList(items: Array(entry.items.prefix(5)), date: entry.date, style: style)
        }
    }
}

// MARK: - Shared food widget pieces

/// The "Use soon" header with the fridge icon.
struct WidgetFoodTitle: View {
    let style: WidgetStyle

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "refrigerator")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(style.palette.avocado)
                .accessibilityHidden(true)
            Text("Use soon")
                .font(style.fonts.font(.widgetTitle))
                .foregroundStyle(style.palette.ink)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Food lines separated by dashed dividers.
struct WidgetFoodList: View {
    let items: [FoodSnapshot]
    let date: Date
    let style: WidgetStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { WidgetDashedDivider(color: style.palette.hairline) }
                WidgetFoodRow(item: item, date: date, style: style)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One food line: name, then its freshness pill.
struct WidgetFoodRow: View {
    @Environment(\.widgetFamily) private var family
    let item: FoodSnapshot
    let date: Date
    let style: WidgetStyle

    var body: some View {
        HStack(spacing: 4) {
            Text(item.name)
                .privacySensitive()
                .font(style.fonts.font(family.bodyRole))
                .foregroundStyle(style.palette.ink)
                .lineLimit(1)
            Spacer(minLength: 2)
            FreshnessPill(freshness: FoodQuery.pill(for: item, now: date), palette: style.palette, fixedSize: 8.5)
        }
        .padding(.vertical, 2.5)
        .accessibilityElement(children: .combine)
    }
}

/// Nothing due: the calm line (the Food tab itself has the funny ones).
struct WidgetFoodCalm: View {
    @Environment(\.widgetFamily) private var family
    let style: WidgetStyle

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "leaf")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(style.palette.avocado)
                .accessibilityHidden(true)
            Text(FoodEmptyLines.calm.title)
                .font(style.fonts.font(.widgetTitle))
                .foregroundStyle(style.palette.ink)
            Text(FoodEmptyLines.calm.message)
                .font(style.fonts.font(family.bodyRole))
                .foregroundStyle(style.palette.ink2)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
