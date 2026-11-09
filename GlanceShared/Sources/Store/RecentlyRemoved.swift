import Foundation

// MARK: - RemovedEntry
/// One thing in "Recently removed", with when it went.
struct RemovedEntry<Item: Codable>: Codable, Identifiable {
    let id: UUID
    let removedAt: Date
    let item: Item
}

// MARK: - RecentlyRemoved
/// The last five deleted lists, or used-up / deleted foods, newest first. The oldest drops off
/// when a sixth arrives. Stored as plain snapshots in UserDefaults (app only, never the widget).
struct RecentlyRemoved<Item: Codable & Identifiable> where Item.ID == UUID {
    /// How many are kept.
    static var limit: Int { 5 }

    let key: String
    let store: UserDefaults

    /// Everything kept, newest first. Unreadable data reads as empty.
    func entries() -> [RemovedEntry<Item>] {
        guard let data = store.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RemovedEntry<Item>].self, from: data)) ?? []
    }

    /// Keeps a copy of something just removed (replacing an older copy of the same thing).
    /// - Parameters:
    ///   - item: the snapshot to keep.
    ///   - now: when it was removed.
    func add(_ item: Item, now: Date = Date()) {
        let entry = RemovedEntry(id: item.id, removedAt: now, item: item)
        let kept = [entry] + entries().filter { $0.id != item.id }
        save(Array(kept.prefix(Self.limit)))
    }

    /// Takes one back out (to restore it).
    /// - Parameter id: the item's id.
    /// - Returns: the item, or nil if it's no longer kept.
    @discardableResult func take(_ id: UUID) -> Item? {
        var all = entries()
        guard let index = all.firstIndex(where: { $0.id == id }) else { return nil }
        let entry = all.remove(at: index)
        save(all)
        return entry.item
    }

    /// Forgets every kept copy (Recently removed → Clear).
    func clear() {
        store.removeObject(forKey: key)
    }

    /// Writes the entries back.
    private func save(_ entries: [RemovedEntry<Item>]) {
        if let data = try? JSONEncoder().encode(entries) { store.set(data, forKey: key) }
    }
}

extension RecentlyRemoved where Item == FoodSnapshot {
    /// Recently used-up or deleted foods.
    /// - Parameter store: defaults to the app's own defaults (tests pass a suite).
    static func food(in store: UserDefaults = .standard) -> Self {
        Self(key: StorageKeys.removedFood, store: store)
    }
}

extension RecentlyRemoved where Item == ThemeSnapshot {
    /// Recently deleted lists.
    /// - Parameter store: defaults to the app's own defaults (tests pass a suite).
    static func lists(in store: UserDefaults = .standard) -> Self {
        Self(key: StorageKeys.removedLists, store: store)
    }
}
