#if DEBUG && targetEnvironment(simulator)
import Foundation
import SwiftData

// MARK: - TestDataSet
/// The shape of `TestData/*.json`. Dates are relative ("daysFromNow", "addedDaysAgo") so the
/// data always looks fresh on the day it's loaded. Debug builds only: none of this ships.
struct TestDataSet: Decodable {
    /// One list: name, SF Symbol token, repeat rule, steps, and which steps start ticked.
    struct List: Decodable {
        let name: String
        let icon: String?
        let `repeat`: String?
        let weekdays: [Int]?
        let dayOfMonth: Int?
        let interval: Int?
        let steps: [String]
        let doneSteps: [Int]?
    }

    /// One food. `where` / `kinds` use the stored raw values (fridge, prepared, canned…).
    struct Food: Decodable {
        let name: String
        let `where`: String?
        let kinds: [String]?
        let labels: [String]?
        let daysFromNow: Int
        let addedDaysAgo: Int?
        let details: String?
    }

    let lists: [List]
    let food: [Food]
}

// MARK: - TestDataLoader
/// Loads a test data file into the app, replacing every list and food. Triggered only when the
/// app is launched with `GLANCE_TEST_DATA=<path>` (see scripts/load-test-data.sh), and only in
/// Debug builds on the simulator, so it can never touch a real user's data.
@MainActor
enum TestDataLoader {
    /// The launch environment variable holding the JSON file's path.
    static let environmentKey = "GLANCE_TEST_DATA"

    /// Loads the file named by the launch environment, if any, and refreshes the widgets.
    /// - Parameters:
    ///   - context: the app's model context.
    ///   - environment: the process environment (injectable for tests).
    static func loadIfRequested(into context: ModelContext,
                                environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let path = environment[environmentKey] else { return }
        do {
            guard let data = FileManager.default.contents(atPath: path) else { throw CocoaError(.fileNoSuchFile) }
            try load(data, into: context)
            WidgetDataBridge.pin(nil)
            WidgetDataBridge.refresh(from: context)
            WidgetDataBridge.refreshFood(from: context)
            print("Glance: loaded test data from \(path)")
        } catch {
            print("Glance: test data not loaded (\(error))")
        }
    }

    /// Replaces every list and food with the file's contents and clears Recently removed.
    /// - Parameters:
    ///   - data: the JSON file's bytes.
    ///   - context: where to write.
    ///   - now: the day the relative dates count from.
    ///   - calendar: calendar for day math.
    ///   - defaults: where Recently removed lives (tests pass a suite).
    static func load(_ data: Data, into context: ModelContext, now: Date = Date(),
                     calendar: Calendar = .current, defaults: UserDefaults = .standard) throws {
        let set = try JSONDecoder().decode(TestDataSet.self, from: data)
        try deleteEverything(in: context)
        // The same caps the app enforces, so a stress file shows what a real user would get.
        for (index, list) in set.lists.prefix(CollectionLimits.lists).enumerated() {
            context.insert(makeTheme(list, sortOrder: index, now: now, calendar: calendar))
        }
        for food in set.food.prefix(CollectionLimits.foods) { context.insert(makeFood(food, now: now, calendar: calendar)) }
        try context.save()
        defaults.removeObject(forKey: StorageKeys.removedLists)
        defaults.removeObject(forKey: StorageKeys.removedFood)
    }

    /// Deletes every list (with its steps) and every food.
    private static func deleteEverything(in context: ModelContext) throws {
        for theme in try context.fetch(FetchDescriptor<Theme>()) { context.delete(theme) }
        for step in try context.fetch(FetchDescriptor<Step>()) { context.delete(step) }
        for food in try context.fetch(FetchDescriptor<FoodItem>()) { context.delete(food) }
    }

    /// A list from its test entry, with the listed steps ticked "now".
    static func makeTheme(_ list: TestDataSet.List, sortOrder: Int, now: Date, calendar: Calendar) -> Theme {
        let steps = list.steps.prefix(CollectionLimits.stepsPerList).enumerated().map {
            Step(text: TextLimits.clamp($1, to: TextLimits.step), sortOrder: $0)
        }
        let theme = Theme(name: TextLimits.clamp(list.name, to: TextLimits.name), iconToken: list.icon ?? ThemeIcons.default, sortOrder: sortOrder, steps: steps)
        theme.recurrence = Recurrence(kind: Recurrence.Kind(rawValue: list.repeat ?? "") ?? .daily,
                                      weekdays: Set(list.weekdays ?? []), dayOfMonth: list.dayOfMonth ?? 1,
                                      interval: list.interval ?? 2)
        theme.repeatAnchor = calendar.startOfDay(for: now)
        for index in list.doneSteps ?? [] where steps.indices.contains(index) {
            steps[index].setComplete(true, now: now)
        }
        return theme
    }

    /// A food from its test entry, dated relative to `now`.
    static func makeFood(_ food: TestDataSet.Food, now: Date, calendar: Calendar) -> FoodItem {
        let added = calendar.date(byAdding: .day, value: -(food.addedDaysAgo ?? 0), to: now) ?? now
        return FoodItem(name: TextLimits.clamp(food.name, to: TextLimits.name),
                        details: TextLimits.clamp(food.details ?? "", to: TextLimits.note, allowsNewlines: true),
                        storage: FoodStorage(rawValue: food.where ?? "") ?? .fridge,
                        kinds: (food.kinds ?? []).compactMap(FoodKind.init(rawValue:)),
                        labels: (food.labels ?? []).compactMap(FoodLabels.normalized).prefix(FoodLabels.maxPicked).map { $0 },
                        useBy: FoodExpiry.useBy(inDays: food.daysFromNow, from: now, calendar: calendar),
                        addedAt: added)
    }
}
#endif
