import Foundation

// MARK: - Theme completion helpers
/// Completion actions expressed on the model, built on the pure CompletionResetPolicy.
/// These mutate SwiftData models, so they live beside the model layer (not in the pure policy).
extension Theme {

    /// Effective completion of the whole list for `now`, honoring the daily reset.
    /// For sweep themes this reflects the last sweep; for per-item themes it is true only
    /// when every step is (still) complete today.
    func isListComplete(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch completionStyle {
        case .sweep:
            return CompletionResetPolicy.isSweepActive(sweptAt: lastSweptAt, now: now, calendar: calendar)
        case .perItem:
            let steps = orderedSteps
            guard !steps.isEmpty else { return false }
            return steps.allSatisfy {
                CompletionResetPolicy.isStillComplete(completedAt: $0.completedAt, now: now, calendar: calendar)
            }
        }
    }

    /// Clears the whole list in one gesture (the fridge-board wipe) and stamps the sweep time.
    /// Also stamps each step so per-item views agree with the swept state.
    func sweepComplete(now: Date = Date()) {
        lastSweptAt = now
        updatedAt = now
        for step in steps { step.setComplete(true, now: now) }
    }

    /// Resets the whole list back to "nothing done" (used when the user un-sweeps or a new day starts).
    func resetCompletion(now: Date = Date()) {
        lastSweptAt = nil
        updatedAt = now
        for step in steps { step.setComplete(false, now: now) }
    }
}
