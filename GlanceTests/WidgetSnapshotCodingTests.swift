import XCTest
@testable import Glance

// MARK: - WidgetSnapshotCodingTests
// Covers: ThemeSnapshot and StepSnapshot Codable (current and legacy JSON), Recurrence Codable.

final class WidgetSnapshotCodingTests: XCTestCase {

    private let anchor = Date(timeIntervalSince1970: 1_793_448_000)    // 2026-10-31 12:00 UTC
    private let listDone = Date(timeIntervalSince1970: 1_793_534_400)  // 2026-11-01 12:00 UTC
    private let stepDone = Date(timeIntervalSince1970: 1_793_530_800)  // 2026-11-01 11:00 UTC

    func testFullSnapshotRoundTripKeepsEveryFieldAndOrder() throws {
        let rule = Recurrence(kind: .weekly, weekdays: [2, 6], dayOfMonth: 15, interval: 3, anchor: anchor)
        let ticked = StepSnapshot(id: UUID(), text: "Wheel bins out", iconEmoji: "🗑️", completedAt: stepDone)
        let plain = StepSnapshot(id: UUID(), text: "Recycling", iconEmoji: nil)
        let bins = ThemeSnapshot(id: UUID(), name: "Bins", colorToken: "clay", iconEmoji: "🗑️",
                                 steps: [ticked, plain], iconToken: "clean", recurrence: rule,
                                 completedAt: listDone)
        let meds = ThemeSnapshot(id: UUID(), name: "Meds", colorToken: "sage", iconEmoji: "💊", steps: [])

        let decoded = try JSONDecoder().decode([ThemeSnapshot].self, from: JSONEncoder().encode([bins, meds]))

        XCTAssertEqual(decoded.map(\.id), [bins.id, meds.id])
        let first = try XCTUnwrap(decoded.first)
        XCTAssertEqual(first.name, "Bins")
        XCTAssertEqual(first.colorToken, "clay")
        XCTAssertEqual(first.iconEmoji, "🗑️")
        XCTAssertEqual(first.iconToken, "clean")
        XCTAssertEqual(first.recurrence, rule)
        XCTAssertEqual(first.recurrence?.weekdays, [2, 6])
        XCTAssertEqual(first.completedAt, listDone)
        XCTAssertEqual(first.steps.map(\.id), [ticked.id, plain.id])
        XCTAssertEqual(first.steps.map(\.text), ["Wheel bins out", "Recycling"])
        XCTAssertEqual(first.steps[0].iconEmoji, "🗑️")
        XCTAssertNil(first.steps[1].iconEmoji)
        XCTAssertEqual(first.steps[0].completedAt, stepDone)
        XCTAssertNil(first.steps[1].completedAt)
        XCTAssertTrue(decoded[1].steps.isEmpty)
        XCTAssertNil(decoded[1].iconToken)
    }

    func testLegacySnapshotWithoutNewKeysDecodesThemAsNil() throws {
        let id = UUID()
        let stepID = UUID()
        let json = #"[{"id":"\#(id.uuidString)","name":"Old","colorToken":"sage","iconEmoji":"x","#
            + #""steps":[{"id":"\#(stepID.uuidString)","text":"Keys","iconEmoji":null}]}]"#
        let decoded = try JSONDecoder().decode([ThemeSnapshot].self, from: Data(json.utf8))
        let theme = try XCTUnwrap(decoded.first)
        XCTAssertEqual(theme.id, id)
        XCTAssertNil(theme.iconToken)
        XCTAssertNil(theme.recurrence)
        XCTAssertNil(theme.completedAt)
        XCTAssertEqual(theme.steps.first?.id, stepID)
        XCTAssertEqual(theme.steps.first?.text, "Keys")
        XCTAssertNil(theme.steps.first?.iconEmoji)
        XCTAssertNil(theme.steps.first?.completedAt)
    }
}
