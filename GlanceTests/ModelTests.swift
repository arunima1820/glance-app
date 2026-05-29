import XCTest
import SwiftData
@testable import Glance

// MARK: - ModelTests
// Covers: Theme.swift, Step.swift
// Each test group maps to a distinct behaviour of the model layer.

final class ModelTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        container = try GlanceStore.makeContainer(inMemory: true)
        context = ModelContext(container)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: Theme — initialisation

    func testThemeDefaultsAreSet() {
        let theme = Theme(name: "Morning", colorToken: "butter", iconEmoji: "☀️")
        XCTAssertFalse(theme.id == UUID(), "ID should be unique per instance")
        XCTAssertEqual(theme.name, "Morning")
        XCTAssertEqual(theme.colorToken, "butter")
        XCTAssertEqual(theme.iconEmoji, "☀️")
        XCTAssertEqual(theme.sortOrder, 0)
        XCTAssertTrue(theme.steps.isEmpty)
        // createdAt and updatedAt should be recent
        XCTAssertLessThanOrEqual(theme.createdAt.timeIntervalSinceNow, 1)
    }

    // MARK: Theme — orderedSteps

    func testOrderedStepsSortsCorrectly() {
        let theme = Theme(name: "Leave the house", colorToken: "sky", iconEmoji: "🚪")
        let s2 = Step(text: "Lock the door", sortOrder: 2)
        let s0 = Step(text: "Grab keys",     sortOrder: 0)
        let s1 = Step(text: "Phone charged", sortOrder: 1)
        theme.steps = [s2, s0, s1] // intentionally shuffled
        XCTAssertEqual(theme.orderedSteps.map(\.text), ["Grab keys", "Phone charged", "Lock the door"])
    }

    func testOrderedStepsEmptyTheme() {
        let theme = Theme(name: "Empty", colorToken: "slate", iconEmoji: "📋")
        XCTAssertTrue(theme.orderedSteps.isEmpty)
    }

    func testOrderedStepsSingleStep() {
        let theme = Theme(name: "One thing", colorToken: "sage", iconEmoji: "1️⃣")
        theme.steps = [Step(text: "Do the thing", sortOrder: 0)]
        XCTAssertEqual(theme.orderedSteps.count, 1)
        XCTAssertEqual(theme.orderedSteps.first?.text, "Do the thing")
    }

    // MARK: Step — initialisation

    func testStepOptionalEmojiIsNilByDefault() {
        let step = Step(text: "Grab keys")
        XCTAssertNil(step.iconEmoji)
        XCTAssertEqual(step.sortOrder, 0)
    }

    func testStepWithExplicitEmoji() {
        let step = Step(text: "Get water", iconEmoji: "💧", sortOrder: 1)
        XCTAssertEqual(step.iconEmoji, "💧")
        XCTAssertEqual(step.sortOrder, 1)
    }

    // MARK: SwiftData — persistence

    func testInsertAndFetchTheme() throws {
        let theme = Theme(name: "Take meds", colorToken: "sage", iconEmoji: "💊", sortOrder: 0)
        context.insert(theme)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Theme>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Take meds")
        XCTAssertEqual(fetched.first?.colorToken, "sage")
    }

    func testMultipleThemesSortedByOrder() throws {
        context.insert(Theme(name: "B", colorToken: "sky", iconEmoji: "B", sortOrder: 1))
        context.insert(Theme(name: "A", colorToken: "sage", iconEmoji: "A", sortOrder: 0))
        context.insert(Theme(name: "C", colorToken: "rose", iconEmoji: "C", sortOrder: 2))
        try context.save()

        let descriptor = FetchDescriptor<Theme>(sortBy: [SortDescriptor(\.sortOrder)])
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.map(\.name), ["A", "B", "C"])
    }

    func testCascadeDeleteRemovesSteps() throws {
        let theme = Theme(name: "Cascade test", colorToken: "slate", iconEmoji: "🗑️")
        let step = Step(text: "Should be deleted", sortOrder: 0)
        theme.steps = [step]
        context.insert(theme)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Step>()).count, 1)

        context.delete(theme)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Theme>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Step>()).count, 0, "Steps should be cascade-deleted")
    }

    func testUpdatingThemeNamePersists() throws {
        let theme = Theme(name: "Old name", colorToken: "sage", iconEmoji: "✏️")
        context.insert(theme)
        try context.save()

        theme.name = "New name"
        theme.updatedAt = Date()
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Theme>())
        XCTAssertEqual(fetched.first?.name, "New name")
    }
}
