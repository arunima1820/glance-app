import XCTest
@testable import Glance

// MARK: - WidgetBridgeTests
// Covers: WidgetDataBridge.swift — ThemeSnapshot and StepSnapshot Codable conformance.
//
// Note: actually writing to UserDefaults requires a provisioned App Group entitlement
// (device/simulator only). These tests cover the encode/decode path which is the
// logic that can break — the UserDefaults write is a one-liner that doesn't need mocking.

final class WidgetBridgeTests: XCTestCase {

    // MARK: Helpers

    private func makeSnapshot(
        name: String = "Take meds",
        colorToken: String = "sage",
        emoji: String = "💊",
        steps: [StepSnapshot] = []
    ) -> ThemeSnapshot {
        ThemeSnapshot(id: UUID(), name: name, colorToken: colorToken, iconEmoji: emoji, steps: steps)
    }

    private func makeStepSnapshot(text: String = "Get water", emoji: String? = "💧") -> StepSnapshot {
        StepSnapshot(id: UUID(), text: text, iconEmoji: emoji)
    }

    // MARK: ThemeSnapshot — Codable

    func testThemeSnapshotRoundTrip() throws {
        let original = makeSnapshot(steps: [makeStepSnapshot()])
        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([ThemeSnapshot].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.id, original.id)
        XCTAssertEqual(decoded.first?.name, original.name)
        XCTAssertEqual(decoded.first?.colorToken, original.colorToken)
        XCTAssertEqual(decoded.first?.iconEmoji, original.iconEmoji)
    }

    func testThemeSnapshotWithNoStepsRoundTrip() throws {
        let original = makeSnapshot(steps: [])
        let data = try JSONEncoder().encode([original])
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
            makeSnapshot(name: "Morning",        colorToken: "butter", emoji: "☀️"),
            makeSnapshot(name: "Take meds",      colorToken: "sage",   emoji: "💊"),
            makeSnapshot(name: "Leave the house",colorToken: "sky",    emoji: "🚪"),
        ]
        let data = try JSONEncoder().encode(snapshots)
        let decoded = try JSONDecoder().decode([ThemeSnapshot].self, from: data)
        XCTAssertEqual(decoded.map(\.name), snapshots.map(\.name))
        XCTAssertEqual(decoded.map(\.colorToken), snapshots.map(\.colorToken))
    }

    // MARK: StepSnapshot — Codable

    func testStepSnapshotWithEmojiRoundTrip() throws {
        let step = makeStepSnapshot(text: "Grab keys", emoji: "🔑")
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(StepSnapshot.self, from: data)
        XCTAssertEqual(decoded.text, "Grab keys")
        XCTAssertEqual(decoded.iconEmoji, "🔑")
    }

    func testStepSnapshotWithNoEmojiRoundTrip() throws {
        let step = makeStepSnapshot(text: "Lock the door", emoji: nil)
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(StepSnapshot.self, from: data)
        XCTAssertEqual(decoded.text, "Lock the door")
        XCTAssertNil(decoded.iconEmoji)
    }

    func testStepSnapshotIDPreservedAcrossRoundTrip() throws {
        let step = makeStepSnapshot()
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(StepSnapshot.self, from: data)
        XCTAssertEqual(decoded.id, step.id)
    }

    // MARK: ThemeSnapshot — field access

    func testThemeSnapshotStepsAreAccessible() {
        let steps = [
            makeStepSnapshot(text: "Step A", emoji: nil),
            makeStepSnapshot(text: "Step B", emoji: "🅱️"),
        ]
        let snapshot = makeSnapshot(steps: steps)
        XCTAssertEqual(snapshot.steps.count, 2)
        XCTAssertEqual(snapshot.steps[0].text, "Step A")
        XCTAssertEqual(snapshot.steps[1].iconEmoji, "🅱️")
    }
}
