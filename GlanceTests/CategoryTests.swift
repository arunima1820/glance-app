import XCTest
import SwiftData
@testable import Glance

// MARK: - CategoryTests
// Covers: GlanceCategory.swift (init defaults and the many-to-many inverses to Theme.categories
// and Step.categories).

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
        let category = GlanceCategory(name: "Urgent")
        XCTAssertEqual(category.name, "Urgent")
        XCTAssertEqual(category.colorToken, "blue")
        XCTAssertEqual(category.sortOrder, 0)
        XCTAssertTrue(category.themes.isEmpty)
        XCTAssertTrue(category.steps.isEmpty)
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
