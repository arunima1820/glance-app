import XCTest
import SwiftData
@testable import Glance

// MARK: - CategoryTests
// Covers: GlanceCategory.swift — initialisation, persistence, and the many-to-many
// relationships to both Theme and Step (a task/routine can sit in several categories).

final class CategoryTests: XCTestCase {

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

    // MARK: Initialisation

    func testCategoryDefaults() {
        let category = GlanceCategory(name: "Urgent", colorToken: "red")
        XCTAssertEqual(category.name, "Urgent")
        XCTAssertEqual(category.colorToken, "red")
        XCTAssertEqual(category.sortOrder, 0)
        XCTAssertTrue(category.themes.isEmpty)
        XCTAssertTrue(category.steps.isEmpty)
    }

    // MARK: Persistence

    func testInsertAndFetchCategory() throws {
        context.insert(GlanceCategory(name: "Errands", colorToken: "blue", sortOrder: 1))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<GlanceCategory>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Errands")
    }

    // MARK: Many-to-many — a category applied to a theme

    func testCategoryAppliedToTheme() throws {
        let theme = Theme(name: "Leave the house", colorToken: "sky", iconEmoji: "🚪")
        let category = GlanceCategory(name: "Morning", colorToken: "amber")
        theme.categories.append(category)
        context.insert(theme)
        try context.save()

        let fetchedTheme = try context.fetch(FetchDescriptor<Theme>()).first
        XCTAssertEqual(fetchedTheme?.categories.first?.name, "Morning")
        // Inverse side is populated automatically.
        let fetchedCategory = try context.fetch(FetchDescriptor<GlanceCategory>()).first
        XCTAssertEqual(fetchedCategory?.themes.first?.name, "Leave the house")
    }

    // MARK: Many-to-many — a step in several categories at once

    func testStepInMultipleCategories() throws {
        let step = Step(text: "Buy stamps")
        let urgent = GlanceCategory(name: "Urgent", colorToken: "red")
        let errands = GlanceCategory(name: "Errands", colorToken: "blue")
        step.categories = [urgent, errands]
        context.insert(step)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Step>()).first
        XCTAssertEqual(Set(fetched?.categories.map(\.name) ?? []), ["Urgent", "Errands"])
    }

    // MARK: A single category spanning both a theme and a step

    func testCategorySpansThemeAndStep() throws {
        let category = GlanceCategory(name: "Health", colorToken: "green")
        let theme = Theme(name: "Take meds", colorToken: "sage", iconEmoji: "💊")
        let step = Step(text: "Refill prescription")
        theme.categories.append(category)
        step.categories.append(category)
        context.insert(theme)
        context.insert(step)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<GlanceCategory>()).first
        XCTAssertEqual(fetched?.themes.count, 1)
        XCTAssertEqual(fetched?.steps.count, 1)
    }
}
