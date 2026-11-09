#if DEBUG && targetEnvironment(simulator)   // the test-data loader only exists here
import XCTest
import SwiftData
@testable import Glance

// MARK: - TestDataLoaderTests
// Covers: Glance/Sources/Debug/TestDataLoader.swift (load(_:into:now:calendar:defaults:),
// loadIfRequested(into:environment:)) and the shipped TestData/*.json files.

@MainActor
final class TestDataLoaderTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var context: ModelContext!

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()
    private let now = Date(timeIntervalSince1970: 1_793_707_200)   // 2026-11-03 12:00 UTC

    override func setUp() async throws {
        suiteName = "glance.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        context = ModelContext(try GlanceStore.makeContainer(inMemory: true))
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        context = nil
    }

    /// A file in the repo's TestData folder (read straight from disk; never bundled).
    private func testData(_ name: String) throws -> Data {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try Data(contentsOf: repo.appending(path: "TestData/\(name)"))
    }

    private func load(_ name: String) throws {
        try TestDataLoader.load(testData(name), into: context, now: now, calendar: calendar, defaults: defaults)
    }

    func testSampleDataLoadsEveryListAndFood() throws {
        try load("sample-data.json")
        let themes = try context.fetch(FetchDescriptor<Theme>(sortBy: [SortDescriptor(\.sortOrder)]))
        let food = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(themes.first?.name, "Leave the house")
        XCTAssertEqual(themes.count, 6)
        XCTAssertEqual(food.count, 14)
    }

    func testRepeatsTicksAndDatesComeThrough() throws {
        try load("sample-data.json")
        let themes = try context.fetch(FetchDescriptor<Theme>())
        let bins = try XCTUnwrap(themes.first { $0.name == "Bins out" })
        XCTAssertEqual(bins.recurrence.kind, .weekly)
        XCTAssertEqual(bins.recurrence.weekdays, [5])
        let evening = try XCTUnwrap(themes.first { $0.name == "Evening wind-down" })
        XCTAssertTrue(evening.isListComplete(now: now, calendar: calendar))
        let food = try context.fetch(FetchDescriptor<FoodItem>())
        let rice = try XCTUnwrap(food.first { $0.name == "Jasmine rice" })
        XCTAssertEqual(Freshness.of(useBy: rice.useBy, now: now, calendar: calendar), .expired)
        XCTAssertTrue(food.allSatisfy { $0.useBy != nil }, "every food has a date")
    }

    func testLoadingReplacesEverythingAndClearsRecentlyRemoved() throws {
        RecentlyRemoved<FoodSnapshot>.food(in: defaults).add(FoodSnapshot(id: UUID(), name: "Old"))
        try load("sample-data.json")
        try load("sample-data.json")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Theme>()).count, 6)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Step>()).count,
                       try context.fetch(FetchDescriptor<Theme>()).reduce(0) { $0 + $1.steps.count })
        XCTAssertTrue(RecentlyRemoved<FoodSnapshot>.food(in: defaults).entries().isEmpty)
    }

    func testEmptyFileWipesEverything() throws {
        try load("sample-data.json")
        try load("empty.json")
        XCTAssertTrue(try context.fetch(FetchDescriptor<Theme>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<FoodItem>()).isEmpty)
    }

    func testNothingHappensWithoutTheLaunchVariable() throws {
        TestDataLoader.loadIfRequested(into: context, environment: [:])
        XCTAssertTrue(try context.fetch(FetchDescriptor<Theme>()).isEmpty)
    }
}
#endif
