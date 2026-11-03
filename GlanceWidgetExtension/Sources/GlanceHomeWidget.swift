import WidgetKit
import SwiftUI
import AppIntents

// MARK: - GlanceHomeWidget
/// Home-screen widget in three sizes. Shows one list (chosen by `WidgetSelection`: auto-pin,
/// the user's tile pin, or the first unfinished list); large adds a Food column when there
/// is food. Display-only: tapping opens that list in the app.
struct GlanceHomeWidget: Widget {
    let kind = "GlanceHomeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectThemeIntent.self,
            provider: GlanceTimelineProvider()
        ) { entry in
            GlanceHomeWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Glance")
        .description("See your tiny list at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - AppIntent for selecting a theme inside the widget

struct SelectThemeIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Glance list"
    static let description = IntentDescription("Shows the list you pinned in the app, or the first one to do.")

    init() {}

    func perform() async throws -> some IntentResult {
        // No settings yet: which list to show is decided by the pin in the app.
        return .result()
    }
}

// MARK: - Timeline provider
// GlanceEntry and placeholder data live in GlanceShared/WidgetEntry.swift
// so they can be unit-tested without importing WidgetKit.

extension GlanceEntry: TimelineEntry {}

struct GlanceTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = GlanceEntry
    typealias Intent = SelectThemeIntent

    func placeholder(in context: Context) -> GlanceEntry {
        GlanceEntry(date: Date(), themes: WidgetPlaceholders.themes, selectedThemeID: nil)
    }

    func snapshot(for configuration: SelectThemeIntent, in context: Context) async -> GlanceEntry {
        Self.makeEntry(configuration)
    }

    /// Now, plus an entry at each of the next 8 midnights, so finished lists reappear (and
    /// weekly ones auto-pin) on the day they repeat even if the app isn't opened.
    func timeline(for configuration: SelectThemeIntent, in context: Context) async -> Timeline<GlanceEntry> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let midnights = (1...8).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let entries = ([Date()] + midnights).map { Self.makeEntry(configuration, at: $0) }
        return Timeline(entries: entries, policy: .atEnd)
    }

    /// The entry for one moment: only lists not yet finished, and the one to show.
    private static func makeEntry(_ configuration: SelectThemeIntent, at date: Date = Date()) -> GlanceEntry {
        let visible = WidgetSelection.visible(loadThemes(), now: date)
        let selected = WidgetSelection.selectedID(visible: visible, pin: WidgetDataBridge.pin,
                                                  configured: nil, now: date)
        return GlanceEntry(date: date, themes: visible, selectedThemeID: selected?.uuidString,
                           food: WidgetDataBridge.readFood())
    }

    /// Live data from the App Group. Placeholders only if the app has never written a
    /// snapshot; an empty list means "no lists", and the widget says so.
    private static func loadThemes() -> [ThemeSnapshot] {
        WidgetDataBridge.readSnapshotIfWritten() ?? WidgetPlaceholders.themes
    }
}

// MARK: - Widget views
// Display-only by design: no check-off here. Taps open the app (glance:// URLs).

/// Resolves the shared palette + font theme for the widget's current appearance.
struct WidgetStyle {
    let palette: Palette
    let fonts: FontTheme

    init(_ scheme: ColorScheme) {
        palette = DesignConfig.shared.palette(for: scheme)
        fonts = FontThemes.theme(WidgetDataBridge.fontThemeID)   // Settings → Title style
    }
}

/// Paper / chalkboard behind the widget.
struct WidgetBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View { WidgetStyle(scheme).palette.paper }
}

struct GlanceHomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GlanceEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        default:
            MediumLargeWidgetView(entry: entry)
        }
    }
}

// MARK: Step list (shared by all sizes)
/// Small step lines (11pt rounded, one line each) with a marker-dot bullet, separated by
/// dashed hairline dividers. Done steps get the app's checkmark + strikethrough and sit
/// at the bottom (widget only).
struct WidgetStepList: View {
    @Environment(\.colorScheme) private var scheme
    let theme: ThemeSnapshot
    let date: Date
    let limit: Int

    var body: some View {
        let style = WidgetStyle(scheme)
        let rows = WidgetSelection.rows(for: theme, now: date)
        let shown = Array(rows.prefix(limit))
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, row in
                if index > 0 { WidgetDashedDivider(color: style.palette.hairline) }
                WidgetStepRow(row: row, style: style)
            }
            if rows.count > limit {
                Text("+\(rows.count - limit) more")
                    .font(style.fonts.font(.widgetBody))
                    .foregroundStyle(style.palette.ink2)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One widget line: dot + text, or (done) checkmark + struck-through text.
struct WidgetStepRow: View {
    let row: WidgetSelection.Row
    let style: WidgetStyle

    var body: some View {
        HStack(spacing: 5) {
            if row.isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(style.palette.marker)
                    .frame(width: 8)
            } else {
                Circle().fill(style.palette.marker).frame(width: 4, height: 4).frame(width: 8)
            }
            Text(row.step.text)
                .font(style.fonts.font(.widgetBody))
                .strikethrough(row.isDone, color: style.palette.ink2)
                .foregroundStyle(row.isDone ? style.palette.ink2 : style.palette.ink)
                .lineLimit(1)
        }
        .padding(.vertical, 2.5)
        .accessibilityElement(children: .combine)
        .accessibilityValue(row.isDone ? "done" : "")
    }
}

/// The app's dashed hairline row divider, sized for the widget.
struct WidgetDashedDivider: View {
    let color: Color

    var body: some View {
        Line()
            .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
    }

    /// A horizontal line across the middle of its rect.
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { $0.move(to: CGPoint(x: rect.minX, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
        }
    }
}

// MARK: Small widget
struct SmallWidgetView: View {
    let entry: GlanceEntry

    var body: some View {
        Group {
            if let theme = entry.selectedTheme {
                VStack(alignment: .leading, spacing: 5) {
                    WidgetThemeTitle(theme: theme)
                    WidgetStepList(theme: theme, date: entry.date, limit: 6)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .widgetURL(GlanceLink.theme(theme.id))
            } else {
                WidgetNothingToDo()
            }
        }
    }
}

/// Icon + name header for one list.
struct WidgetThemeTitle: View {
    @Environment(\.colorScheme) private var scheme
    let theme: ThemeSnapshot

    var body: some View {
        let style = WidgetStyle(scheme)
        HStack(spacing: 4) {
            Image(systemName: ThemeIcons.symbolName(for: theme.iconToken ?? ThemeIcons.default))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(style.palette.marker)
                .accessibilityHidden(true)
            Text(theme.name)
                .font(style.fonts.font(.widgetTitle))
                .foregroundStyle(style.palette.ink)
                .lineLimit(1)
        }
    }
}

// MARK: Empty state
/// Shown when there are no lists at all.
struct WidgetNothingToDo: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let style = WidgetStyle(scheme)
        VStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(style.palette.mustard)
                .accessibilityHidden(true)
            Text("Nothing to do right now!")
                .font(style.fonts.font(.widgetTitle))
                .foregroundStyle(style.palette.ink)
            Text("Enjoy the quiet.")
                .font(style.fonts.font(.widgetBody))
                .foregroundStyle(style.palette.ink2)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(GlanceLink.open)
    }
}

// MARK: Medium / Large widget
/// Header shows only the list being shown (other lists' names stay private).
/// Large: tasks on the left, food on the right, but only when there is food to show.
struct MediumLargeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: GlanceEntry

    private var showsFood: Bool { family == .systemLarge && !entry.food.isEmpty }

    var body: some View {
        if entry.selectedTheme == nil && !showsFood {
            WidgetNothingToDo()
        } else {
            HStack(alignment: .top, spacing: 10) {
                tasksColumn
                if showsFood {
                    WidgetVerticalDivider(color: WidgetStyle(scheme).palette.ink2.opacity(0.4))
                    WidgetFoodSection(items: entry.food)
                }
            }
        }
    }

    @ViewBuilder private var tasksColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let theme = entry.selectedTheme {
                WidgetThemeTitle(theme: theme)
                WidgetStepList(theme: theme, date: entry.date, limit: family == .systemLarge ? 16 : 5)
                    .widgetURL(GlanceLink.theme(theme.id))
            } else {
                WidgetNothingToDo()
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Dashed vertical rule between the tasks and food columns.
struct WidgetVerticalDivider: View {
    let color: Color

    var body: some View {
        VLine()
            .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(width: 1)
    }

    /// A vertical line down the middle of its rect.
    private struct VLine: Shape {
        func path(in rect: CGRect) -> Path {
            Path { $0.move(to: CGPoint(x: rect.midX, y: rect.minY)); $0.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)) }
        }
    }
}

// MARK: Food section (large widget)
/// The groceries column: soonest-to-expire first, each with a freshness pill (text + color).
struct WidgetFoodSection: View {
    @Environment(\.colorScheme) private var scheme
    let items: [FoodSnapshot]

    var body: some View {
        let style = WidgetStyle(scheme)
        let sorted = items.sorted { $0.useByDate < $1.useByDate }.prefix(12)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "refrigerator")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(style.palette.avocado)
                    .accessibilityHidden(true)
                Text("Food")
                    .font(style.fonts.font(.widgetTitle))
                    .foregroundStyle(style.palette.ink)
            }
            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, item in
                if index > 0 { WidgetDashedDivider(color: style.palette.hairline) }
                WidgetFoodRow(item: item)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One food line: name, then its freshness pill.
struct WidgetFoodRow: View {
    @Environment(\.colorScheme) private var scheme
    let item: FoodSnapshot

    var body: some View {
        let style = WidgetStyle(scheme)
        let fresh = Freshness.of(useBy: item.useByDate)
        HStack(spacing: 4) {
            Text(item.name)
                .font(style.fonts.font(.widgetBody))
                .foregroundStyle(style.palette.ink)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(fresh.label)
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                .foregroundStyle(Palettes.fridgeMarker.light.ink)   // dark ink on every pill (contrast)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(pillColor(fresh, style.palette), in: Capsule())
        }
        .padding(.vertical, 2.5)
    }

    private func pillColor(_ fresh: Freshness, _ palette: Palette) -> Color {
        switch fresh {
        case .expired: return palette.marker.opacity(0.45)
        case .days: return palette.mustard.opacity(0.6)
        case .weeks: return palette.avocado.opacity(0.45)
        }
    }
}
