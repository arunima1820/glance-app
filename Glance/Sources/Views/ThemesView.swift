import SwiftUI
import SwiftData

// MARK: - ThemesView  (Screen A: the Lists tab)
/// All routines as paper cards in a 2-column grid, a dashed "New list" tile last,
/// and the nav-bar "+" (no floating button). Tapping a card opens StepsView; the pin in a
/// card's corner shows that list on the widget (one tap); long-press a card to mark it all done
/// or delete it (after a confirm alert; lists have no Undo bar). Deleted lists wait in
/// "Recently removed" (last 5), opened from a quiet link pinned bottom-left, ready to restore.
struct ThemesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Theme.sortOrder) private var themes: [Theme]

    @State private var showingAddTheme = false
    /// Lists mid-delete (popping off screen): hidden everywhere so they can't be reopened.
    @State private var pendingDeletes: Set<UUID> = []
    @State private var removed: [RemovedEntry<ThemeSnapshot>] = []
    @State private var showingRemoved = false
    /// The list a long-press Delete is asking about (shows the confirm alert).
    @State private var confirmingDelete: Theme?
    /// The tile showing the dust-and-dots burst after long-press → Mark all done.
    @State private var celebratingID: UUID?
    @Environment(\.glanceNow) private var now
    @State private var path: [UUID] = []
    /// Set by a widget deep link; this view opens that list, then clears it.
    @Binding var linkedThemeID: UUID?
    /// The list pinned to the widget (shared with the widget through the App Group).
    @AppStorage(WidgetDataBridge.pinnedKey, store: WidgetDataBridge.defaults) private var pinnedID: String?
    /// Observed so the pins redraw when the user pins/unpins (the value is read via the bridge).
    @AppStorage(WidgetDataBridge.pinnedAtKey, store: WidgetDataBridge.defaults) private var pinnedAt: Double?

    private let columns = [GridItem(.flexible(), spacing: Metrics.l), GridItem(.flexible(), spacing: Metrics.l)]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if shownThemes.isEmpty { emptyBoard } else { grid }
            }
            .paperBackground(palette)
            .safeAreaInset(edge: .bottom) {
                RecentlyRemovedLink(title: "Recently removed", count: removed.count) { showingRemoved = true }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .paperBars(palette)
            .navigationDestination(for: UUID.self) { id in
                if let theme = shownThemes.first(where: { $0.id == id }) {
                    StepsView(theme: theme, onDelete: { delete(theme) })
                }
            }
            .sheet(isPresented: $showingAddTheme) { EditThemeView(theme: nil) }
            .sheet(isPresented: $showingRemoved) {
                RecentlyRemovedSheet(title: "Recently removed", rows: removedRows, onRestore: restore) {
                    RecentlyRemoved<ThemeSnapshot>.lists().clear()
                    reloadRemoved()
                }
            }
            .confirmDelete("Delete \u{201C}\(confirmingDelete?.name ?? "")\u{201D}?", isPresented: isConfirmingDelete,
                           message: "You can restore it from Recently removed.") { [target = confirmingDelete] in
                if let target { delete(target) }
            }
            .onAppear(perform: reloadRemoved)
            .onAppear(perform: openLinkedTheme)
            .onChange(of: linkedThemeID) { openLinkedTheme() }
        }
    }

    /// All lists as cards, with the "New list" tile last.
    private var grid: some View {
        ScrollView {
            PageHeader(title: AppInfo.displayName)
            LazyVGrid(columns: columns, spacing: Metrics.l) {
                ForEach(shownThemes) { theme in
                    ZStack(alignment: .topTrailing) {
                        NavigationLink(value: theme.id) { ThemeCardView(theme: theme) }
                            .buttonStyle(.plain)
                            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: Metrics.corner))
                            .contextMenu { tileMenu(theme) }
                        // Finished lists are off the widget until they repeat, so no pin until then.
                        if !theme.isListComplete(now: max(now, Date())) {
                            WidgetPinButton(isPinned: theme.id == pinnedThemeID) { togglePin(theme) }
                        }
                    }
                    .overlay {
                        if celebratingID == theme.id { DoneBurst { celebratingID = nil } }
                    }
                    .zIndex(celebratingID == theme.id ? 1 : 0)   // the burst draws over neighbouring tiles
                }
                if canAddList {
                    Button { showingAddTheme = true } label: { DashedTile(title: "New list") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("New list")
                } else {
                    DashedTile(title: "Board full (\(CollectionLimits.lists))")
                        .accessibilityLabel("The board is full: \(CollectionLimits.lists) lists")
                }
            }
            .padding(.horizontal, Metrics.l)
            .padding(.bottom, Metrics.xl)
        }
    }

    /// No lists: a calm, centered invitation to make one.
    private var emptyBoard: some View {
        EmptyBoard(symbol: "sparkles", title: "A clean board.",
                   message: "Start with one small routine, like taking meds or leaving the house. You can add more any time.",
                   actionTitle: "Create a list") { showingAddTheme = true }
    }

    /// Room for another list (`CollectionLimits.lists`).
    private var canAddList: Bool {
        CollectionLimits.hasRoom(themes.count, under: CollectionLimits.lists)
    }

    /// Every list except ones being deleted.
    private var shownThemes: [Theme] {
        themes.filter { !pendingDeletes.contains($0.id) }
    }

    /// The list pinned to the widget on purpose (user pin or auto-pin), by the widget's own
    /// rules. nil when the widget is just showing its fallback, so no tile looks pinned then.
    private var pinnedThemeID: UUID? {
        _ = (pinnedID, pinnedAt, now)   // re-evaluate when the pin or the day changes
        let moment = Date()
        let visible = WidgetSelection.visible(shownThemes.map { WidgetDataBridge.snapshot(of: $0, now: moment) },
                                              now: moment)
        return WidgetSelection.explicitID(visible: visible, pin: WidgetDataBridge.pin, now: moment)
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingAddTheme = true } label: { Image(systemName: "plus") }
                .disabled(!canAddList)
                .accessibilityLabel("New list")
        }
    }

    // MARK: Helpers

    /// Long-press on a tile (it lifts off the board): mark all done (or bring it back), or delete.
    /// - Parameter theme: the pressed list.
    @ViewBuilder private func tileMenu(_ theme: Theme) -> some View {
        let done = theme.isListComplete(now: max(now, Date()))
        if !theme.steps.isEmpty {
            Button { setAllDone(theme, !done) } label: {
                Label(done ? "Bring it back" : "Mark all done", systemImage: done ? "arrow.uturn.backward" : "checkmark")
            }
        }
        Button(role: .destructive) { askToDelete(theme) } label: { Label("Delete list", systemImage: "trash") }
    }

    /// Long-press → Delete list: asks first, with the same centred alert as everywhere else.
    /// Waits for the menu to finish closing, or iOS can drop the alert.
    /// - Parameter theme: the pressed list.
    private func askToDelete(_ theme: Theme) {
        Task { @MainActor in
            try? await Task.sleep(for: Motion.afterMenu)
            confirmingDelete = theme
        }
    }

    /// Drives the confirm alert from `confirmingDelete`.
    private var isConfirmingDelete: Binding<Bool> {
        Binding(get: { confirmingDelete != nil }, set: { if !$0 { confirmingDelete = nil } })
    }

    /// Ticks every step (or clears them all) straight from the tile, like "all done!", with the
    /// same dust-and-dots burst over the tile.
    /// - Parameters:
    ///   - theme: the list.
    ///   - complete: true to tick all, false to bring it back.
    private func setAllDone(_ theme: Theme, _ complete: Bool) {
        theme.setAllDone(complete)
        try? modelContext.save()
        WidgetDataBridge.refresh(from: modelContext)
        guard complete, !reduceMotion else { return }
        Task { @MainActor in
            try? await Task.sleep(for: Motion.afterMenu)   // let the long-press menu close first
            celebratingID = theme.id
        }
    }

    /// One tap: pin this list to the widget, or unpin it if it's the pinned one.
    /// - Parameter theme: the tapped list.
    private func togglePin(_ theme: Theme) {
        WidgetDataBridge.pin(theme.id == pinnedThemeID ? nil : theme.id)
    }

    /// Opens the list a widget tap pointed at (replacing whatever was open).
    private func openLinkedTheme() {
        guard let id = linkedThemeID else { return }
        linkedThemeID = nil
        guard shownThemes.contains(where: { $0.id == id }) else { return }
        path = [id]
    }

    /// Leaves the deleted list's screen first, then deletes once the pop has finished, so the
    /// closing screen never reads a deleted model. Clears the widget pin if it pointed here.
    /// - Parameter theme: the list to delete.
    private func delete(_ theme: Theme) {
        guard !pendingDeletes.contains(theme.id), !theme.isDeleted else { return }   // already going
        let id = theme.id
        let wasOpen = !path.isEmpty
        pendingDeletes.insert(id)
        path = []
        Task { @MainActor in
            if wasOpen { try? await Task.sleep(for: .milliseconds(450)) }   // let the pop animation finish
            if pinnedID == id.uuidString { WidgetDataBridge.pin(nil) }
            RecentlyRemoved<ThemeSnapshot>.lists().add(WidgetDataBridge.snapshot(of: theme))
            modelContext.delete(theme)
            try? modelContext.save()
            pendingDeletes.remove(id)
            WidgetDataBridge.refresh(from: modelContext)
            reloadRemoved()
        }
    }

    /// Brings a deleted list back (fresh, nothing ticked) at the end of the grid.
    /// - Parameter id: the list's id.
    private func restore(_ id: UUID) {
        guard let snapshot = RecentlyRemoved<ThemeSnapshot>.lists().take(id) else { return }
        let nextOrder = (themes.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(Theme.restored(from: snapshot, sortOrder: nextOrder))
        try? modelContext.save()
        WidgetDataBridge.refresh(from: modelContext)
        reloadRemoved()
    }

    /// Re-reads Recently removed from storage.
    private func reloadRemoved() {
        removed = RecentlyRemoved<ThemeSnapshot>.lists().entries()
    }

    /// Recently removed, ready to draw: name, step count, and the steps for the preview.
    private var removedRows: [RemovedRow] {
        removed.map { entry in
            let count = entry.item.steps.count
            return RemovedRow(id: entry.id, title: entry.item.name,
                              detail: "\(count) step\(count == 1 ? "" : "s")",
                              removedAt: entry.removedAt, previewLines: entry.item.steps.map(\.text))
        }
    }
}

// MARK: - ThemeCardView
/// One routine as a floating paper tile: icon + name, step count, category magnets.
struct ThemeCardView: View {
    @Environment(\.glanceNow) private var now
    let theme: Theme

    var body: some View {
        GlanceTile(symbol: ThemeIcons.symbolName(for: theme.iconToken), title: theme.name,
                   subtitle: stepCountLabel, trailingClearance: isDone ? 0 : Metrics.pinClearance,
                   isQuiet: isDone) {
            magnets
        }
        .accessibilityHint("Opens this list")
    }

    /// Up to two category magnets (dot + name).
    @ViewBuilder private var magnets: some View {
        let shown = theme.categories.sorted { $0.sortOrder < $1.sortOrder }.prefix(2)
        if !shown.isEmpty {
            HStack(spacing: 8) {
                ForEach(Array(shown)) { MagnetDot(name: $0.name, colorToken: $0.colorToken) }
            }
        }
    }

    /// Finished for this period: the tile fades back in place (it never moves).
    private var isDone: Bool {
        theme.isListComplete(now: max(now, Date()))
    }

    /// "4 steps", or once finished "Done · back tomorrow" ("Done" for a one-time list).
    /// The list is hidden on the widget meanwhile.
    private var stepCountLabel: String {
        let moment = max(now, Date())
        guard isDone else { return "\(theme.steps.count) step\(theme.steps.count == 1 ? "" : "s")" }
        guard let next = theme.recurrence.nextStart(after: moment) else { return "Done" }
        return "Done · back " + Recurrence.dayLabel(next, now: moment)
    }
}

// MARK: - WidgetPinButton
/// The one-tap "show on widget" pin in a tile's corner: filled marker pin on the list the
/// widget shows (tap again to unpin), a quiet outline pin on the rest. 44pt tap target.
struct WidgetPinButton: View {
    @Environment(\.palette) private var palette
    let isPinned: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isPinned ? palette.marker : palette.ink2.opacity(0.6))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPinned ? "Showing on widget. Tap to unpin" : "Show on widget")
        .accessibilityAddTraits(isPinned ? .isSelected : [])
    }
}

