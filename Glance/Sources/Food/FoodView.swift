import SwiftUI
import SwiftData

// MARK: - FoodView  (the Food tab)
/// Every food as paper tiles, soonest to use first (or newest first, from the sort menu).
/// One forgiving search box (typos and related words are fine) plus a Fridge / Freezer /
/// Pantry switch narrows them. Long-press a tile for Used it up / Delete. "used it up!" and
/// Delete keep the
/// food in "Recently used up" (last 5, behind a quiet link after the tiles) and show a short
/// Undo bar.
struct FoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    @Environment(\.glanceNow) private var now
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \FoodItem.addedAt, order: .reverse) private var items: [FoodItem]
    @AppStorage(StorageKeys.foodSort) private var sort: FoodSort = .expiry

    /// Set by a widget deep link; this view opens that food, then clears it.
    @Binding var linkedFoodID: UUID?
    @State private var path: [UUID] = []
    @State private var search = ""
    @State private var storage: FoodStorage?
    @FocusState private var searchFocused: Bool
    @State private var adding: NewFood?
    /// Foods mid-removal (popping off screen): hidden everywhere so they can't be reopened.
    @State private var pendingRemovals: Set<UUID> = []
    @State private var removed: [RemovedEntry<FoodSnapshot>] = []
    @State private var undo: UndoNotice?
    @State private var showingRemoved = false
    /// Tiles being wiped away by the duster (long-press → Used it up).
    @State private var wipingIDs: Set<UUID> = []

    private let columns = [GridItem(.flexible(), spacing: Metrics.l), GridItem(.flexible(), spacing: Metrics.l)]

    var body: some View {
        NavigationStack(path: $path) {
            page
            .paperBackground(palette)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .paperBars(palette)
            .safeAreaInset(edge: .bottom) { bottomRow }
            .navigationDestination(for: UUID.self) { id in destination(id) }
            .sheet(item: $adding) { EditFoodView(item: nil, prefilledName: $0.name) }
            .sheet(isPresented: $showingRemoved) {
                RecentlyRemovedSheet(title: "Recently used up", rows: removedRows, onRestore: restore) {
                    RecentlyRemoved<FoodSnapshot>.food().clear()
                    reloadRemoved()
                }
            }
            .onAppear(perform: reloadRemoved)
            .onAppear(perform: openLinkedFood)
            .onChange(of: linkedFoodID) { openLinkedFood() }
        }
    }

    // MARK: Content

    /// No food: the title, then the empty board centred in the space left. Otherwise the
    /// scrolling search + tiles.
    @ViewBuilder private var page: some View {
        if shownItems.isEmpty {
            VStack(spacing: 0) {
                PageHeader(title: "Food")
                emptyBoard
            }
        } else {
            ScrollView {
                PageHeader(title: "Food")
                browser
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    /// Search, the storage switch, then the tiles (or "No … right now").
    private var browser: some View {
        VStack(spacing: Metrics.m) {
            FoodSearchField(text: $search, focused: $searchFocused)
            storageSwitch
            if results.isEmpty { noMatches } else { grid }
        }
        .padding(.horizontal, Metrics.l)
    }

    /// All / Fridge / Freezer / Pantry.
    private var storageSwitch: some View {
        Picker("Where", selection: $storage) {
            Text("All").tag(FoodStorage?.none)
            ForEach(FoodStorage.allCases) { Text($0.label).tag(Optional($0)) }
        }
        .pickerStyle(.segmented)
    }

    /// The food tiles, then the dashed "New food" tile.
    private var grid: some View {
        LazyVGrid(columns: columns, spacing: Metrics.l) {
            ForEach(results) { item in
                NavigationLink(value: item.id) { FoodTile(item: item, now: max(now, Date())) }
                    .buttonStyle(.plain)
                    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: Metrics.corner))
                    .contextMenu { tileMenu(item.id) }
                    .opacity(wipingIDs.contains(item.id) ? 0.15 : 1)
                    .animation(.easeIn(duration: DusterWipe.duration), value: wipingIDs.contains(item.id))
                    .overlay {
                        if wipingIDs.contains(item.id) { DusterWipe { finishWipe(item.id) } }
                    }
                    .zIndex(wipingIDs.contains(item.id) ? 1 : 0)   // the duster draws over neighbouring tiles
            }
            if canAddFood {
                Button { adding = NewFood(name: "") } label: { DashedTile(title: "New food") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New food")
            } else {
                DashedTile(title: "Kitchen full (\(CollectionLimits.foods))")
                    .accessibilityLabel("Full: \(CollectionLimits.foods) foods")
            }
        }
        .padding(.top, Metrics.xs)
    }

    /// Nothing matches: say so, and offer to add what they searched for.
    private var noMatches: some View {
        let term = search.trimmingCharacters(in: .whitespaces)
        let title = term.isEmpty ? "Nothing in the \(storage?.label.lowercased() ?? "kitchen")" : "No \(term) right now"
        return VStack(spacing: Metrics.m) {
            Text(title).font(fonts.font(.cardTitle)).foregroundStyle(palette.ink)
            Button { adding = NewFood(name: term) } label: {
                MarkerSwooshLabel(title: term.isEmpty ? "Add food" : "Add \(term)")
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Metrics.xl)
    }

    /// No food at all: the funny line of the day and one way in.
    private var emptyBoard: some View {
        let line = FoodEmptyLines.ofTheDay(max(now, Date()))
        return EmptyBoard(symbol: "refrigerator", title: line.title, message: line.message,
                          actionTitle: "Add food") { adding = NewFood(name: "") }
    }

    /// Pinned above the tab bar: the Undo bar while there's something to undo, otherwise the
    /// quiet "Recently used up · 3 ›" link (only when something's there).
    @ViewBuilder private var bottomRow: some View {
        if let undo {
            UndoBar(message: undo.message, onUndo: { restore(undo.id) },
                    onDismiss: { withAnimation { self.undo = nil } })
        } else {
            RecentlyRemovedLink(title: "Recently used up", count: removed.count) { showingRemoved = true }
        }
    }

    /// Sort menu and "+".
    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(FoodSort.allCases) { Text($0.label).tag($0) }
                }
            } label: { Image(systemName: "arrow.up.arrow.down") }
            .accessibilityLabel("Sort food")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { adding = NewFood(name: "") } label: { Image(systemName: "plus") }
                .disabled(!canAddFood)
                .accessibilityLabel("New food")
        }
    }

    /// Long-press on a tile (it lifts off the board): used it up, or delete. Both can be undone.
    /// - Parameter id: the pressed food's id.
    @ViewBuilder private func tileMenu(_ id: UUID) -> some View {
        if let item = shownItems.first(where: { $0.id == id }) {
            Button { wipeAway(item) } label: { Label("Used it up", systemImage: "checkmark") }
            Button(role: .destructive) { remove(item, usedUp: false) } label: { Label("Delete", systemImage: "trash") }
        }
    }

    /// The opened food, if it still exists.
    /// - Parameter id: the food's id.
    @ViewBuilder private func destination(_ id: UUID) -> some View {
        if let item = shownItems.first(where: { $0.id == id }) {
            FoodDetailView(item: item, onUsedUp: { remove(item, usedUp: true) },
                           onDelete: { remove(item, usedUp: false) })
        }
    }

    // MARK: Data

    /// Room for another food (`CollectionLimits.foods`).
    private var canAddFood: Bool {
        CollectionLimits.hasRoom(items.count, under: CollectionLimits.foods)
    }

    /// Every food except ones being removed.
    private var shownItems: [FoodItem] {
        items.filter { !pendingRemovals.contains($0.id) }
    }

    /// What the grid shows: filtered by the search box and switch, in the chosen order.
    private var results: [FoodSnapshot] {
        let all = shownItems.map(\.snapshot)
        return FoodQuery.sorted(FoodQuery.filter(all, text: search, storage: storage), by: sort)
    }

    /// Recently used up, ready to draw.
    private var removedRows: [RemovedRow] {
        removed.map { entry in
            let food = entry.item
            return RemovedRow(id: entry.id, title: food.name, detail: FoodQuery.subtitle(for: food),
                              removedAt: entry.removedAt,
                              previewLines: [food.details ?? ""].filter { !$0.isEmpty })
        }
    }
}

// MARK: - FoodView actions
extension FoodView {
    /// Leaves the food's screen first, keeps a copy in Recently used up, then deletes it once
    /// the pop has finished (so the closing screen never reads a deleted model).
    /// - Parameters:
    ///   - item: the food.
    ///   - usedUp: true for "used it up!", false for Delete (changes the Undo wording).
    func remove(_ item: FoodItem, usedUp: Bool) {
        guard !pendingRemovals.contains(item.id), !item.isDeleted else { return }   // already going
        let id = item.id, name = item.name
        let wasOpen = !path.isEmpty
        pendingRemovals.insert(id)
        path = []
        Task { @MainActor in
            if wasOpen { try? await Task.sleep(for: .milliseconds(450)) }   // let the pop finish
            RecentlyRemoved<FoodSnapshot>.food().add(item.snapshot)
            modelContext.delete(item)
            save()
            pendingRemovals.remove(id)
            reloadRemoved()
            showUndo(UndoNotice(id: id, message: "\(name) \(usedUp ? "used up" : "deleted")"))
        }
    }

    /// Long-press → Used it up: the duster wipes the tile off the board, then it's removed
    /// (straight away with Reduce Motion on). It starts once the long-press menu has closed;
    /// otherwise it plays underneath the lifted tile.
    /// - Parameter item: the food.
    func wipeAway(_ item: FoodItem) {
        guard !reduceMotion else { remove(item, usedUp: true); return }
        let id = item.id
        guard !wipingIDs.contains(id) else { return }   // a second tap while it's wiping
        Task { @MainActor in
            try? await Task.sleep(for: Motion.afterMenu)
            wipingIDs.insert(id)
        }
    }

    /// The wipe finished: remove the food for real.
    /// - Parameter id: the food's id.
    func finishWipe(_ id: UUID) {
        wipingIDs.remove(id)
        if let item = shownItems.first(where: { $0.id == id }) { remove(item, usedUp: true) }
    }

    /// Brings a food back from Recently used up (or the Undo bar).
    /// - Parameter id: the food's id.
    func restore(_ id: UUID) {
        guard let snapshot = RecentlyRemoved<FoodSnapshot>.food().take(id) else { return }
        modelContext.insert(FoodItem.restored(from: snapshot))
        save()
        reloadRemoved()
        withAnimation { undo = nil }
    }

    /// Shows the Undo bar and tells VoiceOver. It hides after a few seconds, except with
    /// VoiceOver on, where it stays until dismissed (no time pressure). A newer one replaces it.
    /// - Parameter notice: what to offer.
    func showUndo(_ notice: UndoNotice) {
        withAnimation { undo = notice }
        AccessibilityNotification.Announcement("\(notice.message). Undo is available.").post()
        guard !voiceOverOn else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            if undo == notice { withAnimation { undo = nil } }
        }
    }

    /// Re-reads Recently used up from storage.
    func reloadRemoved() {
        removed = RecentlyRemoved<FoodSnapshot>.food().entries()
    }

    /// Opens the food a widget tap pointed at (replacing whatever was open).
    func openLinkedFood() {
        guard let id = linkedFoodID else { return }
        linkedFoodID = nil
        guard shownItems.contains(where: { $0.id == id }) else { return }
        path = [id]
    }

    /// Saves and rewrites the widgets' food snapshot.
    func save() {
        try? modelContext.save()
        WidgetDataBridge.refreshFood(from: modelContext)
    }
}

// MARK: - NewFood
/// A request to open the New food sheet, optionally with a name already filled in.
struct NewFood: Identifiable {
    let id = UUID()
    let name: String
}

// MARK: - UndoNotice
/// What the Undo bar is offering to bring back.
struct UndoNotice: Equatable {
    let id: UUID
    let message: String
}
