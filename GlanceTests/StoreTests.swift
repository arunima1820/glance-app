import XCTest
import SwiftData
@testable import Glance

// MARK: - StoreTests
// Covers: GlanceStore.swift
// Verifies the container factory, schema registration, and basic persistence operations.

final class StoreTests: XCTestCase {

    // MARK: Container creation

    func testInMemoryContainerCreates() throws {
        XCTAssertNoThrow(try GlanceStore.makeContainer(inMemory: true))
    }

    func testInMemoryContainerStartsEmpty() throws {
        let container = try GlanceStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let themes = try context.fetch(FetchDescriptor<Theme>())
        XCTAssertTrue(themes.isEmpty)
    }

    // MARK: Basic insert / fetch

    func testInsertThemeThenFetch() throws {
        let container = try GlanceStore.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let theme = Theme(name: "Store test", colorToken: "lavender", iconEmoji: "🔬", sortOrder: 0)
        context.insert(theme)
        try context.save()

        let results = try context.fetch(FetchDescriptor<Theme>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Store test")
    }

    func testInsertThemeWithStepsThenFetch() throws {
        let container = try GlanceStore.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let theme = Theme(name: "With steps", colorToken: "sky", iconEmoji: "📋")
        theme.steps = [
            Step(text: "Step one", sortOrder: 0),
            Step(text: "Step two", sortOrder: 1),
        ]
        context.insert(theme)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Theme>()).first
        XCTAssertEqual(fetched?.steps.count, 2)
        XCTAssertEqual(fetched?.orderedSteps.map(\.text), ["Step one", "Step two"])
    }

    func testDeleteThemeRemovesIt() throws {
        let container = try GlanceStore.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let theme = Theme(name: "To delete", colorToken: "clay", iconEmoji: "🗑️")
        context.insert(theme)
        try context.save()

        context.delete(theme)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Theme>())
        XCTAssertTrue(remaining.isEmpty)
    }

    // MARK: App Group identifier format

    func testAppGroupIdentifierHasExpectedFormat() {
        // Must start with "group." — required by iOS App Group convention.
        XCTAssertTrue(
            GlanceStore.appGroupIdentifier.hasPrefix("group."),
            "App Group ID must start with 'group.' — current value: \(GlanceStore.appGroupIdentifier)"
        )
    }
}
