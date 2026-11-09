import Foundation

// MARK: - Theme restore
extension Theme {
    /// Rebuilds a deleted list from its snapshot (Recently removed → Restore): same id, name,
    /// icon, repeat and steps, with every tick cleared so it comes back fresh.
    /// - Parameters:
    ///   - snapshot: the saved copy.
    ///   - sortOrder: where it goes in the grid.
    ///   - now: when it's restored (the repeat cycle counts from here).
    static func restored(from snapshot: ThemeSnapshot, sortOrder: Int, now: Date = Date()) -> Theme {
        let steps = snapshot.steps.enumerated().map { index, step in
            Step(text: step.text, iconEmoji: step.iconEmoji, sortOrder: index)
        }
        let theme = Theme(id: snapshot.id, name: snapshot.name, colorToken: snapshot.colorToken,
                          iconToken: snapshot.iconToken ?? ThemeIcons.default,
                          iconEmoji: snapshot.iconEmoji, sortOrder: sortOrder, steps: steps)
        theme.recurrence = snapshot.recurrence ?? Recurrence()
        theme.repeatAnchor = now
        return theme
    }
}
