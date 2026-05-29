import XCTest
@testable import Glance

// MARK: - StarterTemplateTests
// Covers: StarterTemplates.swift
// Verifies the seed data that new users see on first launch is well-formed.

final class StarterTemplateTests: XCTestCase {

    private var templates: [Theme]!

    override func setUp() {
        templates = StarterTemplates.all()
    }

    // MARK: Collection-level

    func testStarterTemplatesAreNonEmpty() {
        XCTAssertFalse(templates.isEmpty)
    }

    func testEachTemplateHasNonEmptyName() {
        for t in templates {
            XCTAssertFalse(t.name.trimmingCharacters(in: .whitespaces).isEmpty,
                           "Template has empty name")
        }
    }

    func testEachTemplateHasNonEmptyIconEmoji() {
        for t in templates {
            XCTAssertFalse(t.iconEmoji.isEmpty,
                           "Template '\(t.name)' has no icon emoji")
        }
    }

    func testEachTemplateHasAtLeastOneStep() {
        for t in templates {
            XCTAssertFalse(t.steps.isEmpty,
                           "Template '\(t.name)' has no steps")
        }
    }

    func testEachTemplateColorTokenIsInPalette() {
        let validTokens = Set(ThemePalette.all.map(\.id))
        for t in templates {
            XCTAssertTrue(validTokens.contains(t.colorToken),
                          "Template '\(t.name)' has unknown colorToken '\(t.colorToken)'")
        }
    }

    func testTemplateNamesAreUnique() {
        let names = templates.map(\.name)
        XCTAssertEqual(names.count, Set(names).count, "Starter template names should be unique")
    }

    // MARK: Step-level

    func testStepsHaveNonEmptyText() {
        for theme in templates {
            for step in theme.steps {
                XCTAssertFalse(step.text.trimmingCharacters(in: .whitespaces).isEmpty,
                               "Step in '\(theme.name)' has empty text")
            }
        }
    }

    func testStepSortOrdersStartAtZero() {
        for theme in templates {
            let minOrder = theme.orderedSteps.first?.sortOrder
            XCTAssertEqual(minOrder, 0,
                           "First step in '\(theme.name)' should have sortOrder 0")
        }
    }

    func testStepSortOrdersAreSequential() {
        for theme in templates {
            let orders = theme.orderedSteps.map(\.sortOrder)
            for (index, order) in orders.enumerated() {
                XCTAssertEqual(order, index,
                               "Step \(index) in '\(theme.name)' has non-sequential sortOrder \(order)")
            }
        }
    }

    func testStepSortOrdersAreUnique() {
        for theme in templates {
            let orders = theme.steps.map(\.sortOrder)
            XCTAssertEqual(orders.count, Set(orders).count,
                           "Template '\(theme.name)' has duplicate step sortOrders")
        }
    }

    // MARK: Tiny-list rule: lists stay short

    func testTemplateStepsRespectTinyListPrinciple() {
        // The spec says lists are designed to be glanced at.
        // A starter template with >7 steps contradicts the product principle.
        for theme in templates {
            XCTAssertLessThanOrEqual(theme.steps.count, 7,
                                     "Starter '\(theme.name)' has too many steps (\(theme.steps.count)) for a tiny list")
        }
    }
}


// MARK: - SettingsEnumTests
// Covers: SettingsView.swift — AppAppearance and FontChoice enums.
// These are small but their mappings are used at runtime for UI behaviour.

final class SettingsEnumTests: XCTestCase {

    // MARK: AppAppearance

    func testSystemAppearanceHasNilColorScheme() {
        XCTAssertNil(AppAppearance.system.colorScheme)
    }

    func testLightAppearanceMapsToLight() {
        XCTAssertEqual(AppAppearance.light.colorScheme, .light)
    }

    func testDarkAppearanceMapsToDark() {
        XCTAssertEqual(AppAppearance.dark.colorScheme, .dark)
    }

    func testHighContrastAppearanceMapsToDark() {
        // High contrast is served through dark mode in v1.
        XCTAssertEqual(AppAppearance.highContrast.colorScheme, .dark)
    }

    func testAllAppearanceCasesHaveNonEmptyLabel() {
        for mode in AppAppearance.allCases {
            XCTAssertFalse(mode.label.isEmpty, "AppAppearance.\(mode.rawValue) has empty label")
        }
    }

    func testAppearanceRawValueMatchesIDForCodability() {
        // rawValue == id is required for @AppStorage to round-trip correctly.
        for mode in AppAppearance.allCases {
            XCTAssertEqual(mode.rawValue, mode.id)
        }
    }

    // MARK: FontChoice

    func testAllFontChoicesHaveNonEmptyLabel() {
        for choice in FontChoice.allCases {
            XCTAssertFalse(choice.label.isEmpty, "FontChoice.\(choice.rawValue) has empty label")
        }
    }

    func testFontChoiceRawValueMatchesIDForCodability() {
        for choice in FontChoice.allCases {
            XCTAssertEqual(choice.rawValue, choice.id)
        }
    }

    func testSystemFontChoiceLabelMentionsSanFrancisco() {
        // The Settings UI promises "San Francisco" for the system option.
        XCTAssertTrue(FontChoice.system.label.contains("San Francisco"),
                      "System font label should mention 'San Francisco' to match the UI copy")
    }
}
