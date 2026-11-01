import XCTest
@testable import Glance

// MARK: - GlanceEntryTests
// Covers: GlanceEntry (selectedTheme, food default) and WidgetPlaceholders.themes.

final class GlanceEntryTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_793_534_400)   // 2026-11-01 12:00 UTC

    private func list(_ name: String) -> ThemeSnapshot {
        ThemeSnapshot(id: UUID(), name: name, colorToken: "sage", iconEmoji: "",
                      steps: [StepSnapshot(id: UUID(), text: "Step", iconEmoji: nil)])
    }

    func testSelectedThemeMatchesID() {
        let themes = [list("Meds"), list("Morning")]
        let entry = GlanceEntry(date: now, themes: themes, selectedThemeID: themes[1].id.uuidString)
        XCTAssertEqual(entry.selectedTheme?.id, themes[1].id)
    }

    func testSelectedThemeFallsBackToFirstForNilOrUnknownID() {
        let themes = [list("Meds"), list("Morning")]
        let unset = GlanceEntry(date: now, themes: themes, selectedThemeID: nil)
        let unknown = GlanceEntry(date: now, themes: themes, selectedThemeID: UUID().uuidString)
        XCTAssertEqual(unset.selectedTheme?.id, themes[0].id)
        XCTAssertEqual(unknown.selectedTheme?.id, themes[0].id)
    }

    func testSelectedThemeIsNilWithoutThemes() {
        XCTAssertNil(GlanceEntry(date: now, themes: [], selectedThemeID: UUID().uuidString).selectedTheme)
    }

    func testFoodDefaultsToEmpty() {
        XCTAssertTrue(GlanceEntry(date: now, themes: [], selectedThemeID: nil).food.isEmpty)
    }

    func testPlaceholdersAreDisplayable() {
        let validIcons = Set(ThemeIcons.all.map(\.id))
        XCTAssertFalse(WidgetPlaceholders.themes.isEmpty)
        for theme in WidgetPlaceholders.themes {
            XCTAssertFalse(theme.name.isEmpty)
            XCTAssertFalse(theme.steps.isEmpty, "'\(theme.name)' has no steps")
            XCTAssertTrue(validIcons.contains(theme.iconToken ?? ""), "'\(theme.name)' lacks a valid icon")
        }
    }
}
