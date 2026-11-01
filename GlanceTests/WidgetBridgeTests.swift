import XCTest
@testable import Glance

// MARK: - WidgetBridgeTests
// Covers: WidgetDataBridge Codable round-trip, GlanceEntry.selectedTheme resolution,
// and GlanceTimelineProvider placeholder content.
//
// Root cause of the "widget shows only emoji" bug — two issues:
//   1. GlanceWidgetColors used named asset catalog colors, but the widget extension
//      has its own bundle with no Assets.car, so all colors resolved to clear/transparent.
//      Text was invisible; only emoji (which ignores foreground color) was visible.
//   2. WidgetDataBridge.readSnapshot() returned [] in dev because App Groups aren't
//      provisioned without a real developer account, so the widget had no data to show.

final class WidgetBridgeTests: XCTestCase {

    // MARK: Codable round-trip

    func testThemeSnapshotRoundTrip() throws {
        let original = makeSnapshot(steps: [makeStep()])
        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([ThemeSnapshot].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.id, original.id)
        XCTAssertEqual(decoded.first?.name, original.name)
        XCTAssertEqual(decoded.first?.colorToken, original.colorToken)
        XCTAssertEqual(decoded.first?.iconEmoji, original.iconEmoji)
    }

    func testThemeSnapshotWithNoStepsRoundTrip() throws {
        let data = try JSONEncoder().encode([makeSnapshot(steps: [])])
        let decoded = try JSONDecoder().decode([ThemeSnapshot].self, from: data)
        XCTAssertTrue(decoded.first?.steps.isEmpty ?? false)
    }

    func testEmptyThemeArrayRoundTrip() throws {
        let data = try JSONEncoder().encode([ThemeSnapshot]())
        let decoded = try JSONDecoder().decode([ThemeSnapshot].self, from: data)
        XCTAssertTrue(decoded.isEmpty)
    }

    func testMultipleThemesRoundTrip() throws {
        let snapshots = [
            makeSnapshot(name: "Morning",         colorToken: "butter", emoji: "☀️"),
            makeSnapshot(name: "Take meds",       colorToken: "sage",   emoji: "💊"),
            makeSnapshot(name: "Leave the house", colorToken: "sky",    emoji: "🚪"),
        ]
        let data = try JSONEncoder().encode(snapshots)
        let decoded = try JSONDecoder().decode([ThemeSnapshot].self, from: data)
        XCTAssertEqual(decoded.map(\.name), snapshots.map(\.name))
    }

    func testStepWithEmojiRoundTrip() throws {
        let step = makeStep(text: "Grab keys", emoji: "🔑")
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(StepSnapshot.self, from: data)
        XCTAssertEqual(decoded.text, "Grab keys")
        XCTAssertEqual(decoded.iconEmoji, "🔑")
    }

    func testStepWithNoEmojiRoundTrip() throws {
        let step = makeStep(text: "Lock the door", emoji: nil)
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(StepSnapshot.self, from: data)
        XCTAssertNil(decoded.iconEmoji)
    }

    // MARK: GlanceEntry.selectedTheme — the logic that decides what the widget displays

    func testSelectedThemeReturnsFirstWhenNoIDSet() {
        let entry = GlanceEntry(date: Date(), themes: makeSampleThemes(), selectedThemeID: nil)
        XCTAssertEqual(entry.selectedTheme?.name, "Take meds",
                       "No selectedThemeID → should show first theme, not nil")
    }

    func testSelectedThemeMatchesByID() {
        let themes = makeSampleThemes()
        let entry = GlanceEntry(date: Date(), themes: themes, selectedThemeID: themes[1].id.uuidString)
        XCTAssertEqual(entry.selectedTheme?.name, themes[1].name)
    }

    func testSelectedThemeFallsBackToFirstForUnknownID() {
        let entry = GlanceEntry(date: Date(), themes: makeSampleThemes(), selectedThemeID: UUID().uuidString)
        XCTAssertEqual(entry.selectedTheme?.name, "Take meds",
                       "Unknown ID → should fall back to first theme, not nil")
    }

    func testSelectedThemeIsNilWhenThemesEmpty() {
        let entry = GlanceEntry(date: Date(), themes: [], selectedThemeID: nil)
        XCTAssertNil(entry.selectedTheme)
    }

    // MARK: Placeholder content — regression test for root cause #2
    // WidgetPlaceholders.themes is the fallback when App Group data is unavailable.
    // If it's empty or steps are missing, the widget shows only the emoji.

    func testPlaceholderThemesAreNonEmpty() {
        XCTAssertFalse(WidgetPlaceholders.themes.isEmpty,
                       "WidgetPlaceholders.themes must not be empty — widget needs fallback content when App Group is unavailable")
    }

    func testPlaceholderThemesAllHaveSteps() {
        for theme in WidgetPlaceholders.themes {
            XCTAssertFalse(theme.steps.isEmpty,
                           "Placeholder theme '\(theme.name)' has no steps — widget would show only the emoji with no list")
        }
    }

    func testPlaceholderThemesAllHaveNames() {
        for theme in WidgetPlaceholders.themes {
            XCTAssertFalse(theme.name.isEmpty, "Placeholder theme has an empty name")
        }
    }

    func testPlaceholderThemesAllHaveEmoji() {
        for theme in WidgetPlaceholders.themes {
            XCTAssertFalse(theme.iconEmoji.isEmpty, "Placeholder theme '\(theme.name)' has no emoji")
        }
    }

    // MARK: Helpers

    private func makeSnapshot(
        name: String = "Take meds",
        colorToken: String = "sage",
        emoji: String = "💊",
        steps: [StepSnapshot] = []
    ) -> ThemeSnapshot {
        ThemeSnapshot(id: UUID(), name: name, colorToken: colorToken, iconEmoji: emoji, steps: steps)
    }

    private func makeStep(text: String = "Get water", emoji: String? = "💧") -> StepSnapshot {
        StepSnapshot(id: UUID(), text: text, iconEmoji: emoji)
    }

    private func makeSampleThemes() -> [ThemeSnapshot] {
        [
            makeSnapshot(name: "Take meds",  colorToken: "sage",   emoji: "💊",
                         steps: [makeStep(text: "Get water")]),
            makeSnapshot(name: "Morning",    colorToken: "butter", emoji: "☀️",
                         steps: [makeStep(text: "Drink water")]),
        ]
    }
}
