import SwiftUI
import SwiftData

// MARK: - StepsView  (Screen B: the glance view)
/// The list you look at. Native `List` on the paper surface, ~9pt rows, no emoji.
/// Tap any row to cross it off; "all done!" crosses off the whole list. Either way, done rows
/// get the same checkmark. An inline row at the end is the only place to add a step.
/// Long-press a step to edit its text or delete it; drag to reorder. A one-time list offers
/// to delete itself once everything is done.
struct StepsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    let theme: Theme
    /// Called when the user deletes this list from the Edit sheet; the parent pops back to
    /// the tiles and performs the delete.
    var onDelete: () -> Void = {}

    @State private var showingEdit = false
    @State private var newStepText = ""
    @FocusState private var addFieldFocused: Bool
    @State private var editingStep: Step?
    @State private var editText = ""
    @State private var offeringDelete = false

    var body: some View {
        if theme.isDeleted {
            Color.clear   // mid-pop after a delete: never touch a deleted model
        } else {
            content
                .alert("Edit step", isPresented: isEditingStep) {
                    TextField("Step", text: $editText)
                    Button("Save", action: commitEdit)
                    Button("Cancel", role: .cancel) {}
                }
                .confirmationDialog("All done! Delete this list?", isPresented: $offeringDelete,
                                    titleVisibility: .visible) {
                    Button("Delete this list", role: .destructive, action: onDelete)
                    Button("Keep it", role: .cancel) {}
                } message: {
                    Text("It's a one-time list, so it won't come back.")
                }
        }
    }

    private var content: some View {
        List {
            Section {
                ForEach(theme.orderedSteps) { step in
                    stepRow(step)
                        .listRowBackground(palette.card)
                        .listRowSeparatorTint(palette.hairline)
                        .contextMenu { stepMenu(step) }
                }
                .onDelete(perform: deleteSteps)
                .onMove(perform: moveSteps)
                addRow
                    .listRowBackground(palette.card)
            } header: {
                listHeader
            } footer: {
                footerHint
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .paperBars(palette)
        .safeAreaInset(edge: .bottom) { sweepBar }
        .sheet(isPresented: $showingEdit) {
            EditThemeView(theme: theme, onDelete: onDelete)
        }
    }

    // MARK: Rows

    /// One tappable step row: the step text (led by a checkmark when done).
    /// - Parameter step: the step to render.
    private func stepRow(_ step: Step) -> some View {
        Button { toggle(step) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                stepText(step)
                    .foregroundStyle(isDone(step) ? palette.ink2 : palette.ink)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())   // whole row is the tap target, not just the glyphs
        }
        .buttonStyle(.plain)
        .accessibilityValue(isDone(step) ? "done" : "not done")
        .accessibilityHint("Double-tap to \(isDone(step) ? "uncheck" : "check off")")
    }

    /// The row text: bold lead word, then plain detail. When done: struck through, led by
    /// the same checkmark as the "all done!" swoosh, inline so it wraps with the text.
    /// - Parameter step: the step to render.
    private func stepText(_ step: Step) -> Text {
        let parts = StepText.split(step.text)
        let done = isDone(step)
        var words = Text(parts.lead).font(fonts.font(.rowLead))
        if !parts.detail.isEmpty {
            // Concatenated Text keeps one wrapping paragraph (2 lines) with two fonts.
            words = words + Text(" " + parts.detail).font(fonts.font(.rowBody))
        }
        words = words.strikethrough(done, color: palette.ink2)
        guard done else { return words }
        let check = Text(Image(systemName: "checkmark"))
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(palette.marker)
        return check + Text(" ") + words
    }

    /// The inline "+ write another item" ghost row at the end of the list.
    private var addRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .foregroundStyle(palette.marker)
                .accessibilityHidden(true)
            TextField("write another item", text: $newStepText)
                .font(fonts.font(.rowBody))
                .foregroundStyle(palette.ink)
                .focused($addFieldFocused)
                .submitLabel(.done)
                .onSubmit(addStep)
        }
        .padding(.vertical, 3)
    }

    // MARK: Sweep bar (whole-list completion)

    @ViewBuilder private var sweepBar: some View {
        if !theme.steps.isEmpty {   // every list gets it, whatever its completion style
            let done = theme.isListComplete()
            HStack {
                Spacer()
                Button { setSweep(complete: !done) } label: { SwooshLabel(done: done) }
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, Metrics.xl)
            .padding(.vertical, Metrics.m)
            .background(palette.paper)   // the list scrolls under the bar; keep the text legible
        }
    }

    // MARK: Toolbar + footer

    /// Edit, in the same marker-swoosh style as "all done!" and Save.
    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingEdit = true } label: { MarkerSwooshLabel(title: "Edit") }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit list")
        }
        .withoutSharedGlass()
    }

    /// The list's name, in the page just above its card (not up in the nav bar by the camera).
    private var listHeader: some View {
        HStack(spacing: Metrics.s) {
            Image(systemName: ThemeIcons.symbolName(for: theme.iconToken))
                .accessibilityHidden(true)
            Text(theme.name)
        }
        .font(fonts.font(.listTitle))   // icon scales with the title text
        .foregroundStyle(palette.ink2)    // subtler than the step text
        .textCase(nil)
        .padding(.bottom, Metrics.xs)
        .accessibilityAddTraits(.isHeader)
    }

    private var footerHint: some View {
        Text("Tap a step to cross it off. Everything resets tomorrow.")
            .font(fonts.font(.caption))
            .foregroundStyle(palette.ink2)
    }

    // MARK: Actions

    /// Whether a step counts as done right now (resets per the list's repeat schedule).
    private func isDone(_ step: Step) -> Bool {
        theme.isDone(step.completedAt)
    }

    private func toggle(_ step: Step) {
        theme.toggle(step)
        save()
        offerDeleteIfOneTimeFinished()
    }

    private func setSweep(complete: Bool) {
        if complete { theme.sweepComplete() } else { theme.resetCompletion() }
        save()
        offerDeleteIfOneTimeFinished()
    }

    /// A finished one-time list offers to delete itself (it won't come back).
    private func offerDeleteIfOneTimeFinished() {
        offeringDelete = theme.recurrence.kind == .oneTime && theme.isListComplete()
    }

    // MARK: Long-press menu, edit, reorder

    /// Long-press actions for one step.
    /// - Parameter step: the pressed step.
    @ViewBuilder private func stepMenu(_ step: Step) -> some View {
        Button { beginEdit(step) } label: { Label("Edit text", systemImage: "pencil") }
        Button(role: .destructive) { delete(step) } label: { Label("Delete", systemImage: "trash") }
    }

    private var isEditingStep: Binding<Bool> {
        Binding(get: { editingStep != nil }, set: { if !$0 { editingStep = nil } })
    }

    private func beginEdit(_ step: Step) {
        editText = step.text
        editingStep = step
    }

    /// Saves the edited text (blank text keeps the old wording).
    private func commitEdit() {
        let text = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let step = editingStep, !text.isEmpty {
            step.text = text
            step.updatedAt = .now
            save()
        }
        editingStep = nil
    }

    private func delete(_ step: Step) {
        modelContext.delete(step)
        save()
    }

    /// Drag to reorder: rewrites sortOrder to match the new order.
    private func moveSteps(from source: IndexSet, to destination: Int) {
        var ordered = theme.orderedSteps
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, step) in ordered.enumerated() { step.sortOrder = index }
        save()
    }

    /// Appends the typed step, keeps the field focused for the next one, refreshes the widget.
    private func addStep() {
        let text = newStepText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let nextOrder = (theme.steps.map(\.sortOrder).max() ?? -1) + 1
        theme.steps.append(Step(text: text, sortOrder: nextOrder))
        theme.updatedAt = .now
        newStepText = ""
        addFieldFocused = true
        save()
    }

    /// Swipe-to-delete for a step (removes that one step only).
    private func deleteSteps(at offsets: IndexSet) {
        let ordered = theme.orderedSteps
        for index in offsets { modelContext.delete(ordered[index]) }
        save()
    }

    private func save() {
        try? modelContext.save()
        WidgetDataBridge.refresh(from: modelContext)
    }
}

// MARK: - SwooshLabel
/// Option D ("marker swoosh") for "all done!". Done state goes quiet.
struct SwooshLabel: View {
    let done: Bool

    var body: some View {
        MarkerSwooshLabel(title: done ? "Done. Tap to bring it back." : "all done!",
                          showsCheck: !done, quiet: done)
    }
}

// MARK: - MarkerSwooshLabel
/// Handwritten action text with a drawn underline, like a note on the board. The app's
/// one button style for primary actions ("all done!", "Create a list").
struct MarkerSwooshLabel: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    let title: String
    var showsCheck = false
    /// Smaller, ink2 text and a faded swoosh (e.g. the done state).
    var quiet = false

    var body: some View {
        HStack(spacing: 5) {
            if showsCheck {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy))
            }
            Text(title).font(quiet ? fonts.font(.caption) : fonts.font(.button))
        }
        .foregroundStyle(quiet ? palette.ink2 : palette.marker)
        .padding(.bottom, 9)
        .overlay(alignment: .bottom) {
            Swoosh()
                .stroke(style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .foregroundStyle(quiet ? palette.ink2.opacity(0.35) : palette.marker)
                .frame(height: 8)
        }
        .contentShape(Rectangle())
    }
}

/// A slightly wavy hand-drawn underline spanning its rect.
struct Swoosh: Shape {
    /// Path from lower-left to upper-right with a gentle S-curve.
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.minX + w * 0.02, y: rect.minY + h * 0.67))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.98, y: rect.minY + h * 0.33),
                      control1: CGPoint(x: rect.minX + w * 0.25, y: rect.minY + h * 0.22),
                      control2: CGPoint(x: rect.minX + w * 0.55, y: rect.minY + h * 0.89))
        return path
    }
}
