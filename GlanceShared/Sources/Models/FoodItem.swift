import Foundation
import SwiftData

// MARK: - FoodItem
/// One food in the fridge, freezer or pantry: what it is, where it lives, and when to use it.
/// Every food saved from the form has a date (canned food gets a long "best by" one).
/// Eggs and the like are one item with one date (no counting).
@Model
final class FoodItem: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    /// The optional description ("Cooked Sunday, in the blue tub").
    var details: String = ""
    var storageRaw: String = FoodStorage.fridge.rawValue
    var kindsRaw: [String] = []
    /// Up to three "Food" labels; the first is the main one.
    var labels: [String] = []
    /// Start of the day to use it by. Always set by the form; nil only on foods saved by
    /// early builds, which show no pill until edited.
    var useBy: Date? = nil
    var addedAt: Date = Date()
    var updatedAt: Date = Date()

    /// - Parameters:
    ///   - name: what it is.
    ///   - details: optional description.
    ///   - storage: where it lives.
    ///   - kinds: what sort of food it is.
    ///   - labels: Food labels, main first.
    ///   - useBy: the use-by day, or nil.
    ///   - addedAt: when it was added.
    init(id: UUID = UUID(), name: String, details: String = "", storage: FoodStorage = .fridge,
         kinds: [FoodKind] = [], labels: [String] = [], useBy: Date? = nil, addedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.details = details
        self.storageRaw = storage.rawValue
        self.kindsRaw = kinds.map(\.rawValue)
        self.labels = labels
        self.useBy = useBy
        self.addedAt = addedAt
        self.updatedAt = addedAt
    }

    /// Where it lives (unknown stored values read as the fridge).
    var place: FoodStorage {
        get { FoodStorage(rawValue: storageRaw) ?? .fridge }
        set { storageRaw = newValue.rawValue }
    }

    /// What sort of food it is, in the standard order (unknown stored values are skipped).
    var kinds: [FoodKind] {
        get { FoodKind.allCases.filter { kindsRaw.contains($0.rawValue) } }
        set { kindsRaw = newValue.map(\.rawValue) }
    }

    /// Canned: a long best-by date, and no pill until it's close.
    var isCanned: Bool { kinds.contains(.canned) }

    /// A plain copy for search, sorting, Recently removed, and the widget.
    var snapshot: FoodSnapshot {
        FoodSnapshot(id: id, name: name, useBy: useBy, storage: place, kinds: kinds,
                     labels: labels, details: details, addedAt: addedAt)
    }

    /// Rebuilds a food from a snapshot (Restore / Undo). Keeps its id and dates.
    /// - Parameter snapshot: the saved copy.
    static func restored(from snapshot: FoodSnapshot) -> FoodItem {
        FoodItem(id: snapshot.id, name: snapshot.name, details: snapshot.details ?? "",
                 storage: snapshot.place, kinds: snapshot.kindList, labels: snapshot.labelList,
                 useBy: snapshot.useBy, addedAt: snapshot.addedAt ?? Date())
    }
}
