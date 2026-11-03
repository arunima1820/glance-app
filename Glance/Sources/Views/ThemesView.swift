import SwiftUI
import SwiftData

// MARK: - ThemesView  (Screen A: the Lists tab)
/// All routines as paper cards in a 2-column grid, a dashed "New list" tile last,
/// and the nav-bar "+" (no floating button). Tapping a card opens StepsView; the pin in a
/// card's corner shows that list on the widget (one tap).
struct ThemesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    @Query(sort: \Theme.sortOrder) private var themes: [Theme]

    @State private var showingAddTheme = false
    /// Lists mid-delete (popping off screen): hidden everywhere so they can't be reopened.
    @State private var pendingDeletes: Set<UUID> = []
    @Environment(\.glanceNow) private var now
    @State private var path: [UUID] = []
    /// Set by a widget deep link; this view opens that list, then clears it.
    @Binding var linkedThemeID: UUID?
    /// The list pinned to the widget (shared with the widget through the App Group).
    @AppStorage(WidgetDataBridge.pinnedKey, store: WidgetDataBridge.defaults) private var pinnedID: String?
    /// Observed so the pins redraw when the user pins/unpins (the value is read via the bridge).
    @AppStorage(WidgetDataBridge.pinnedAtKey, store: WidgetDataBridge.defaults) private var pinnedAt: Double?
    /// Starters are added once, ever, so deleting every list leaves a truly empty board.
    @AppStorage("glance.didSeedStarters") private var didSeedStarters = false

    private let columns = [GridItem(.flexible(), spacing: Metrics.l), GridItem(.flexible(), spacing: Metrics.l)]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if shownThemes.isEmpty { emptyBoard } else { grid }
            }
            .paperBackground(palette)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .paperBars(palette)
            .navigationDestination(for: UUID.self) { id in
                if let theme = shownThemes.first(where: { $0.id == id }) {
                    StepsView(theme: theme, onDelete: { delete(theme) })
                }
            }
            .sheet(isPresented: $showingAddTheme) { EditThemeView(theme: nil) }
            .onAppear(perform: seedIfNeeded)
            .onAppear(perform: openLinkedTheme)
            .onChange(of: linkedThemeID) { openLinkedTheme() }
        }
    }

    /// All lists as cards, with the "New list" tile last.
    private var grid: some View {
        ScrollView {
            pageHeader
            LazyVGrid(columns: columns, spacing: Metrics.l) {
                ForEach(shownThemes) { theme in
                    ZStack(alignment: .topTrailing) {
                        NavigationLink(value: theme.id) { ThemeCardView(theme: theme) }
                            .buttonStyle(.plain)
                        WidgetPinButton(isPinned: theme.id == pinnedThemeID) { togglePin(theme) }
                    }
                }
                Button { showingAddTheme = true } label: { DashedTile(title: "New list") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New list")
            }
            .padding(.horizontal, Metrics.l)
            .padding(.bottom, Metrics.xl)
        }
    }

    /// The wordmark as a left-aligned page header, matching the list header on Steps.
    private var pageHeader: some View {
        Text(AppInfo.displayName)
            .font(fonts.font(.appTitle))
            .foregroundStyle(palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.l)
            .padding(.top, Metrics.s)
            .padding(.bottom, Metrics.m)
            .accessibilityAddTraits(.isHeader)
    }

    /// No lists: a calm, centered invitation to make one.
    private var emptyBoard: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(palette.mustard)
                .accessibilityHidden(true)
            Text("A clean board.")
                .font(fonts.font(.cardTitle))
                .foregroundStyle(palette.ink)
            Text("Start with one small routine, like taking meds or leaving the house. You can add more any time.")
                .font(fonts.font(.rowBody))
                .foregroundStyle(palette.ink2)
                .multilineTextAlignment(.center)
            Button { showingAddTheme = true } label: { MarkerSwooshLabel(title: "Create a list", showsCheck: false) }
                .buttonStyle(.plain)
                .padding(.top, 6)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .accessibilityLabel("New list")
        }
    }

    // MARK: Helpers

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
        let id = theme.id
        pendingDeletes.insert(id)
        path = []
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))   // let the pop animation finish
            if pinnedID == id.uuidString { WidgetDataBridge.pin(nil) }
            modelContext.delete(theme)
            try? modelContext.save()
            pendingDeletes.remove(id)
            WidgetDataBridge.refresh(from: modelContext)
        }
    }

    /// First launch only: insert the starter lists so the screen is never blank.
    /// Runs once ever (existing installs that already have lists just set the flag).
    private func seedIfNeeded() {
        guard !didSeedStarters else { return }
        didSeedStarters = true
        guard themes.isEmpty else { return }
        for theme in StarterTemplates.all() { modelContext.insert(theme) }
        try? modelContext.save()
        WidgetDataBridge.refresh(from: modelContext)
    }
}

// MARK: - AppInfo
/// The single place the displayed app name lives ("Glance" is a placeholder).
enum AppInfo {
    static let displayName = "Glance"
}

// MARK: - ThemeCardView
/// One routine as a floating paper tile: icon + cardTitle name, step count, category magnets.
struct ThemeCardView: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    @Environment(\.glanceNow) private var now
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            titleLine
            Text(stepCountLabel)
                .font(fonts.font(.caption))
                .foregroundStyle(palette.ink2)
            magnets
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .padding(Metrics.m)
        .paperCard(palette)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(theme.name), \(stepCountLabel)")
        .accessibilityHint("Opens this list")
    }

    /// Icon at the start of the line, same size as the name, wrapping as one line of text.
    private var titleLine: some View {
        let icon = Text(Image(systemName: ThemeIcons.symbolName(for: theme.iconToken)))
            .foregroundStyle(palette.marker)
        return (icon + Text(" " + theme.name).foregroundStyle(palette.ink))
            .font(fonts.font(.cardTitle))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.trailing, 22)   // clear of the widget pin in the corner
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

    /// "4 steps", plus "· done, back Tue" (or a date if further than a week) for a finished
    /// repeating list (hidden on the widget meanwhile).
    private var stepCountLabel: String {
        let moment = max(now, Date())
        let count = "\(theme.steps.count) step\(theme.steps.count == 1 ? "" : "s")"
        guard theme.isListComplete(now: moment) else { return count }
        guard let next = theme.recurrence.nextStart(after: moment) else { return count + " · done" }
        return count + " · done, back " + Recurrence.dayLabel(next, now: moment)
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

