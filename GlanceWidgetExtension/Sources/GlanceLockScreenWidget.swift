import WidgetKit
import SwiftUI

// MARK: - GlanceLockScreenWidget
/// Lock-screen widget (.accessoryRectangular / .accessoryCircular).
/// Very small; iOS renders it tinted/monochrome, so we rely on text + shape, not color.
/// Shows: current theme name + icon + first step (or two).
struct GlanceLockScreenWidget: Widget {
    let kind = "GlanceLockScreenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectThemeIntent.self,
            provider: GlanceTimelineProvider()
        ) { entry in
            GlanceLockScreenWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Glance (Lock Screen)")
        .description("Your current theme's first step at a glance.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct GlanceLockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GlanceEntry

    var body: some View {
        if let theme = entry.selectedTheme {
            switch family {
            case .accessoryRectangular:
                rectangularView(theme: theme)
            case .accessoryInline:
                inlineView(theme: theme)
            case .accessoryCircular:
                circularView(theme: theme)
            default:
                rectangularView(theme: theme)
            }
        } else {
            Text("Glance").font(.caption)
        }
    }

    private func rectangularView(theme: ThemeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(theme.name, systemImage: "list.bullet")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            if let first = theme.steps.first {
                Text(first.text)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "glance://theme/\(theme.id.uuidString)"))
        .accessibilityLabel("\(theme.name). \(theme.steps.first?.text ?? "")")
    }

    private func inlineView(theme: ThemeSnapshot) -> some View {
        Label {
            Text(theme.steps.first?.text ?? theme.name)
        } icon: {
            Text(theme.iconEmoji)
        }
        .widgetURL(URL(string: "glance://theme/\(theme.id.uuidString)"))
    }

    private func circularView(theme: ThemeSnapshot) -> some View {
        Text(theme.iconEmoji)
            .font(.system(size: 28))
            .widgetURL(URL(string: "glance://theme/\(theme.id.uuidString)"))
            .accessibilityLabel(theme.name)
    }
}
