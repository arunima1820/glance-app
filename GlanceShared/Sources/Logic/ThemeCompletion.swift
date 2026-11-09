import Foundation

// MARK: - Theme completion helpers
/// Completion actions expressed on the model, built on the pure `Recurrence` schedule.
/// These mutate SwiftData models, so they live beside the model layer (not in `Recurrence`).
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

    /// Start of this list's current period: ticks stamped before it no longer count. Work it
    /// out once when checking many steps (finding it walks back through the calendar).
    func currentPeriodStart(now: Date = Date(), calendar: Calendar = .current) -> Date {
        recurrence.periodStart(atOrBefore: now, calendar: calendar)
    }

    /// Whether a tick still counts, given the period start from `currentPeriodStart`.
    /// - Parameters:
    ///   - date: when the step was ticked (nil = not ticked).
    ///   - start: the current period's start.
    static func counts(_ date: Date?, since start: Date) -> Bool {
        guard let date else { return false }
        return date >= start
    }

    /// True when the list has steps and every one is (still) complete.
    func allStepsDone(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard !steps.isEmpty else { return false }
        let start = currentPeriodStart(now: now, calendar: calendar)
        return steps.allSatisfy { Self.counts($0.completedAt, since: start) }
    }

    /// When the list was finished in the current period (nil if it isn't finished).
    /// Written to the widget snapshot so the widget can hide it until it comes round again.
    func listCompletedAt(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard isListComplete(now: now, calendar: calendar) else { return nil }
        let start = currentPeriodStart(now: now, calendar: calendar)
        return steps.compactMap(\.completedAt).filter { Self.counts($0, since: start) }.max()
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
        updatedAt = now
    }

    /// "all done!": ticks every step (that's what makes the list complete).
    func sweepComplete(now: Date = Date()) {
        updatedAt = now
        for step in steps { step.setComplete(true, now: now) }
    }

    /// Un-ticks every step (the user un-sweeps). Period resets need no call: `Recurrence`
    /// decides which ticks still count.
    func resetCompletion(now: Date = Date()) {
        updatedAt = now
        for step in steps { step.setComplete(false, now: now) }
    }

    /// Saves a new repeat rule. Ticks the OLD rule had already expired are cleared first, so a
    /// rule that looks further back (e.g. switching to One-time) can't revive old ticks; the
    /// cycle then restarts today. No-op when the rule is unchanged.
    /// - Parameters:
    ///   - rule: the new rule.
    ///   - now: the moment of the change (injectable for tests).
    ///   - calendar: calendar for the period math.
    func changeRecurrence(to rule: Recurrence, now: Date = Date(), calendar: Calendar = .current) {
        let old = recurrence
        let sameRule = old.kind == rule.kind && old.weekdays == rule.weekdays
            && old.dayOfMonth == rule.dayOfMonth && old.interval == rule.interval
        guard !sameRule else { return }
        for step in steps where !old.isStillComplete(step.completedAt, now: now, calendar: calendar) {
            step.completedAt = nil
        }
        recurrence = rule
        repeatAnchor = now
        updatedAt = now
    }
}
