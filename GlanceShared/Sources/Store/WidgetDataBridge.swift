import Foundation
import WidgetKit

// MARK: - WidgetDataBridge
/// Writes a lightweight snapshot of themes into UserDefaults(suiteName:) — the App Group
/// shared defaults — so the widget extension can read it without touching SwiftData.
/// After any edit, call `writeSnapshot(_:)` then `WidgetCenter.shared.reloadAllTimelines()`.

struct ThemeSnapshot: Codable, Identifiable {
    let id: UUID
    let name: String
    let colorToken: String
    let iconEmoji: String
    let steps: [StepSnapshot]
}

struct StepSnapshot: Codable, Identifiable {
    let id: UUID
    let text: String
    let iconEmoji: String?
}

enum WidgetDataBridge {
    private static let key = "glance.widget.snapshot"
    nonisolated(unsafe) private static let defaults = UserDefaults(suiteName: GlanceStore.appGroupIdentifier)!

    static func writeSnapshot(_ themes: [Theme]) {
        let snapshots = themes.map { theme in
            ThemeSnapshot(
                id: theme.id,
                name: theme.name,
                colorToken: theme.colorToken,
                iconEmoji: theme.iconEmoji,
                steps: theme.orderedSteps.map { step in
                    StepSnapshot(id: step.id, text: step.text, iconEmoji: step.iconEmoji)
                }
            )
        }
        if let data = try? JSONEncoder().encode(snapshots) {
            defaults.set(data, forKey: key)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func readSnapshot() -> [ThemeSnapshot] {
        guard let data = defaults.data(forKey: key),
              let snapshots = try? JSONDecoder().decode([ThemeSnapshot].self, from: data)
        else { return [] }
        return snapshots
    }
}
