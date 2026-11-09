import Foundation

// MARK: - Step editing
/// Edits made from a list's screen (add, rename, reorder), kept out of the view so they're
/// testable. Each method stamps `updatedAt`; the caller saves and refreshes the widget.
extension Step {
    /// Replaces the text (trimmed, capped). Blank text keeps the old wording.
    /// - Parameters:
    ///   - raw: what the user typed.
    ///   - now: the moment of the change.
    /// - Returns: whether the text changed.
    @discardableResult func rename(to raw: String, now: Date = Date()) -> Bool {
        let text = TextLimits.clamp(raw, to: TextLimits.step)
        guard !text.isEmpty, text != self.text else { return false }
        self.text = text
        updatedAt = now
        return true
    }
}

extension Theme {
    /// Adds a step at the end of the list.
    /// - Parameters:
    ///   - raw: what the user typed.
    ///   - now: the moment of the change.
    /// - Returns: the new step, or nil for blank text or a full list (`CollectionLimits`).
    @discardableResult func addStep(_ raw: String, now: Date = Date()) -> Step? {
        let text = TextLimits.clamp(raw, to: TextLimits.step)
        guard !text.isEmpty, CollectionLimits.hasRoom(steps.count, under: CollectionLimits.stepsPerList) else { return nil }
        let step = Step(text: text, sortOrder: (steps.map(\.sortOrder).max() ?? -1) + 1)
        steps.append(step)
        updatedAt = now
        return step
    }

    /// Drag to reorder (same meaning as SwiftUI's `onMove`): moves the steps at `source` so
    /// they land before the step that was at `destination`, then renumbers `sortOrder`.
    /// - Parameters:
    ///   - source: positions being moved (in display order).
    ///   - destination: the position they're dropped at.
    ///   - now: the moment of the change.
    func moveSteps(fromOffsets source: IndexSet, toOffset destination: Int, now: Date = Date()) {
        var ordered = orderedSteps
        let moving = source.map { ordered[$0] }
        for index in source.sorted(by: >) { ordered.remove(at: index) }
        let insertAt = destination - source.filter { $0 < destination }.count
        ordered.insert(contentsOf: moving, at: min(max(insertAt, 0), ordered.count))
        for (index, step) in ordered.enumerated() { step.sortOrder = index }
        updatedAt = now
    }

    /// Moves one step a place up (-1) or down (+1): VoiceOver's "Move up" / "Move down",
    /// for people who can't drag.
    /// - Parameters:
    ///   - step: the step to move.
    ///   - offset: -1 for up, +1 for down.
    ///   - now: the moment of the change.
    /// - Returns: false when it's already at that end.
    @discardableResult func moveStep(_ step: Step, by offset: Int, now: Date = Date()) -> Bool {
        let ordered = orderedSteps
        guard let index = ordered.firstIndex(where: { $0.id == step.id }),
              ordered.indices.contains(index + offset) else { return false }
        moveSteps(fromOffsets: [index], toOffset: offset > 0 ? index + offset + 1 : index + offset, now: now)
        return true
    }

    /// Ticks every step ("all done!") or clears them all ("bring it back").
    /// - Parameters:
    ///   - complete: true to tick all, false to clear.
    ///   - now: the moment of the change.
    func setAllDone(_ complete: Bool, now: Date = Date()) {
        if complete { sweepComplete(now: now) } else { resetCompletion(now: now) }
    }
}
