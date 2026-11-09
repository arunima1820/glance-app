import XCTest
@testable import Glance

// MARK: - FoodItemTests
// Covers: GlanceShared/Sources/Models/FoodItem.swift (place, kinds, isCanned, snapshot,
// restored(from:)) and FoodSnapshot's fallbacks in WidgetEntry.swift.

final class FoodItemTests: XCTestCase {

    private let day = Date(timeIntervalSince1970: 1_793_534_400)   // 2026-11-01 12:00 UTC

    func testDefaults() {
        let item = FoodItem(name: "Milk")
        XCTAssertEqual(item.place, .fridge)
        XCTAssertTrue(item.kinds.isEmpty)
        XCTAssertNil(item.useBy)
        XCTAssertFalse(item.isCanned)
    }

    func testKindsKeepStandardOrderAndSkipUnknownValues() {
        let item = FoodItem(name: "x", kinds: [.thaw, .snack])
        item.kindsRaw.append("mystery")
        XCTAssertEqual(item.kinds, [.snack, .thaw])
    }

    func testUnknownStorageReadsAsFridge() {
        let item = FoodItem(name: "x", storage: .pantry)
        item.storageRaw = "garage"
        XCTAssertEqual(item.place, .fridge)
    }

    func testCannedSnapshotKeepsItsBestByDate() {
        let tin = FoodItem(name: "Beans", storage: .pantry, kinds: [.canned], useBy: day)
        XCTAssertTrue(tin.isCanned)
        XCTAssertEqual(tin.snapshot.useBy, day)
    }

    func testSnapshotRoundTripsThroughRestore() {
        let rice = FoodItem(name: "Rice", details: "Blue tub", storage: .freezer, kinds: [.prepared],
                            labels: ["Rice", "Chicken"], useBy: day, addedAt: day)
        let back = FoodItem.restored(from: rice.snapshot)
        XCTAssertEqual(back.id, rice.id)
        XCTAssertEqual(back.snapshot, rice.snapshot)
    }

    func testSnapshotFallbacksWhenFieldsAreMissing() {
        let bare = FoodSnapshot(id: UUID(), name: "Old")
        XCTAssertEqual(bare.place, .fridge)
        XCTAssertTrue(bare.kindList.isEmpty)
        XCTAssertTrue(bare.labelList.isEmpty)
        XCTAssertFalse(bare.isCanned)
    }

    func testOldSnapshotJSONStillDecodes() throws {
        let id = UUID()
        let json = #"[{"id":"\#(id.uuidString)","name":"Milk"}]"#
        let decoded = try JSONDecoder().decode([FoodSnapshot].self, from: Data(json.utf8))
        XCTAssertEqual(decoded.first?.id, id)
        XCTAssertNil(decoded.first?.useBy)
    }
}
