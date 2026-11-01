import Foundation

// MARK: - Theme completion helpers
/// Completion actions expressed on the model, built on the pure `Recurrence` schedule.
/// These mutate SwiftData models, so they live beside the model layer (not in the pure policy).
extension Theme {

    /// Whether a tick stamped at `date` still counts now, per this list's repeat schedule
    /// (daily = same calendar day; weekly = since this week's day; one-time = forever).
    func isDone(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        recurrence.isStillComplete(date, now: now, calendar: calendar)
    }

    /// Effective completion of the whole list for `now`, honoring the repeat schedule:
    /// every step ticked this period. ("all done!" ticks each step, so it counts; a step added
    /// afterwards is unticked, so the list is no longer finished.)
    func isListComplete(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        allStepsDone(now: now, calendar: calendar)
    }

    /// True when the list has steps and every one is (still) complete.
    func allStepsDone(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let steps = orderedSteps
        guard !steps.isEmpty else { return false }
        return steps.allSatisfy { isDone($0.completedAt, now: now, calendar: calendar) }
    }

    /// When the list was finished in the current period (nil if it isn't finished).
    /// Written to the widget snapshot so the widget can hide it until it comes round again.
    func listCompletedAt(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard isListComplete(now: now, calendar: calendar) else { return nil }
        return steps.compactMap(\.completedAt).filter { isDone($0, now: now, calendar: calendar) }.max()
    }

    /// Flips one step's done state (tap-to-check, offered in every list).
    /// Un-checking a step also lifts a whole-list sweep, so the list never reads "done" with
    /// an unchecked row on it.
    /// - Parameters:
    ///   - step: a step in this theme.
    ///   - now: the moment to stamp (injectable for tests).
    ///   - calendar: calendar for the reset comparison.
    func toggle(_ step: Step, now: Date = Date(), calendar: Calendar = .current) {
        let wasDone = isDone(step.completedAt, now: now, calendar: calendar)
        step.setComplete(!wasDone, now: now)
        if wasDone { lastSweptAt = nil }
        updatedAt = now
    }

    /// Clears the whole list in one gesture (the fridge-board wipe) and stamps the sweep time.
    /// Ticks each step (that's what makes the list complete); `lastSweptAt` is kept as a record.
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
