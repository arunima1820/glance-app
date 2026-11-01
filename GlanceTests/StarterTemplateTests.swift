import XCTest
@testable import Glance

// MARK: - StarterTemplateTests
// Covers: GlanceShared/Sources/SampleData/StarterTemplates.swift

final class StarterTemplateTests: XCTestCase {

    private var templates: [Theme]!

    override func setUp() {
        super.setUp()
        templates = StarterTemplates.all()
    }

    override func tearDown() {
        templates = nil
        super.tearDown()
    }

    func testStarterTemplatesAreNonEmpty() {
        XCTAssertFalse(templates.isEmpty)
    }

    func testEachTemplateHasNonEmptyName() {
        for t in templates {
            XCTAssertFalse(t.name.trimmingCharacters(in: .whitespaces).isEmpty, "Template has empty name")
        }
    }

    func testTemplateNamesAreUnique() {
        let names = templates.map(\.name)
        XCTAssertEqual(names.count, Set(names).count)
    }

    func testEachTemplateHasBetweenOneAndSevenSteps() {
        for t in templates {
            XCTAssertFalse(t.steps.isEmpty, "Template '\(t.name)' has no steps")
            XCTAssertLessThanOrEqual(t.steps.count, 7, "Starter '\(t.name)' is too long for a tiny list")
        }
    }

    func testStepsHaveNonEmptyText() {
        for t in templates {
            for step in t.steps {
                XCTAssertFalse(step.text.trimmingCharacters(in: .whitespaces).isEmpty,
                               "Step in '\(t.name)' has empty text")
            }
        }
    }

    func testStepSortOrdersAreSequentialFromZero() {
        for t in templates {
            let orders = t.orderedSteps.map(\.sortOrder)
            XCTAssertEqual(orders, Array(0..<t.steps.count), "Template '\(t.name)' has sortOrders \(orders)")
        }
    }

    func testEachTemplateColorTokenIsInPalette() {
        let valid = Set(ThemePalette.all.map(\.id))
        for t in templates {
            XCTAssertTrue(valid.contains(t.colorToken), "Template '\(t.name)' has unknown colorToken '\(t.colorToken)'")
        }
    }

    func testEachTemplateIconTokenIsInIconSet() {
        let valid = Set(ThemeIcons.all.map(\.id))
        for t in templates {
            XCTAssertTrue(valid.contains(t.iconToken), "Template '\(t.name)' has unknown iconToken '\(t.iconToken)'")
        }
    }

    func testTemplatesRepeatDailyByDefault() {
        for t in templates {
            XCTAssertEqual(t.recurrence.kind, .daily, "Template '\(t.name)' should repeat daily")
        }
    }
}
