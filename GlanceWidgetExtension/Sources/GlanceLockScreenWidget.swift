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
            Text("Nothing to do right now!")
                .font(.caption)
                .widgetURL(URL(string: "\(GlanceLink.scheme)://open"))
        }
    }

    private func rectangularView(theme: ThemeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(theme.name, systemImage: ThemeIcons.symbolName(for: theme.iconToken ?? ThemeIcons.default))
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
        .widgetURL(GlanceLink.theme(theme.id))
        .accessibilityLabel("\(theme.name). \(theme.steps.first?.text ?? "")")
    }

    private func inlineView(theme: ThemeSnapshot) -> some View {
        Label(theme.steps.first?.text ?? theme.name,
              systemImage: ThemeIcons.symbolName(for: theme.iconToken ?? ThemeIcons.default))
        .widgetURL(GlanceLink.theme(theme.id))
    }

    private func circularView(theme: ThemeSnapshot) -> some View {
        Image(systemName: ThemeIcons.symbolName(for: theme.iconToken ?? ThemeIcons.default))
            .font(.system(size: 22, weight: .semibold))
            .widgetURL(GlanceLink.theme(theme.id))
            .accessibilityLabel(theme.name)
    }
}
