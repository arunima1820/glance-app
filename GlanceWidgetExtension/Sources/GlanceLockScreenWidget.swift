import WidgetKit
import SwiftUI

// MARK: - GlanceLockScreenWidget
/// Lock-screen widget (.accessoryRectangular / .accessoryInline / .accessoryCircular).
/// Very small; iOS renders it tinted/monochrome, so we rely on text + shape, not color.
/// Shows the list's name and next step, marked privacy-sensitive (iOS hides it while locked
/// when Lock Screen widget data is turned off). With Settings → "Hide details on Lock Screen"
/// on, it only ever shows "Glance · 3 to do".
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
        .description("Your list's next step at a glance.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct GlanceLockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GlanceEntry

    var body: some View {
        if let theme = entry.selectedTheme, WidgetDataBridge.hidesLockScreenDetails() {
            privateView(theme: theme)
        } else if let theme = entry.selectedTheme {
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
                .widgetURL(GlanceLink.open)
        }
    }

    /// The first step not yet ticked (the home widget sinks ticked steps; this matches it).
    /// - Parameter theme: the shown list.
    private func nextStep(_ theme: ThemeSnapshot) -> StepSnapshot? {
        WidgetSelection.rows(for: theme, now: entry.date).first { !$0.isDone }?.step
    }

    /// "Hide details on Lock Screen": no list name, no step text, just how many are left.
    @ViewBuilder private func privateView(theme: ThemeSnapshot) -> some View {
        let left = WidgetSelection.rows(for: theme, now: entry.date).filter { !$0.isDone }.count
        Group {
            switch family {
            case .accessoryCircular:
                Text("\(left)").font(.system(size: 22, weight: .semibold))
            case .accessoryInline:
                Text("Glance · \(left) to do")
            default:
                VStack(alignment: .leading, spacing: 2) {
                    Label("Glance", systemImage: "checklist").font(.caption.weight(.semibold))
                    Text("\(left) to do").font(.caption2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .widgetURL(GlanceLink.open)
        .accessibilityLabel("Glance, \(left) to do")
    }

    /// The list's name and its next step.
    private func rectangularView(theme: ThemeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(theme.name, systemImage: ThemeIcons.symbolName(for: theme.iconToken ?? ThemeIcons.default))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .privacySensitive()
            if let next = nextStep(theme) {
                Text(next.text)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .privacySensitive()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(GlanceLink.theme(theme.id))
        .accessibilityLabel("\(theme.name). \(nextStep(theme)?.text ?? "")")
    }

    /// One line: the next step (or the list's name).
    private func inlineView(theme: ThemeSnapshot) -> some View {
        Label(nextStep(theme)?.text ?? theme.name,
              systemImage: ThemeIcons.symbolName(for: theme.iconToken ?? ThemeIcons.default))
        .privacySensitive()
        .widgetURL(GlanceLink.theme(theme.id))
    }

    /// Just the list's icon.
    private func circularView(theme: ThemeSnapshot) -> some View {
        Image(systemName: ThemeIcons.symbolName(for: theme.iconToken ?? ThemeIcons.default))
            .font(.system(size: 22, weight: .semibold))
            .widgetURL(GlanceLink.theme(theme.id))
            .accessibilityLabel(theme.name)
    }
}
