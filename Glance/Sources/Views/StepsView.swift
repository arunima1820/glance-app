import SwiftUI
import SwiftData

// MARK: - StepsView  (Screen B: the glance view)
/// The list you look at. Native `List` on the paper surface, ~9pt rows, no emoji.
/// Tap a row to cross it off; "all done!" crosses off the whole list (same checkmark either way).
/// Double-tap a row to edit its text in place; long-press and drag to reorder; swipe left to
/// delete. An inline row at the end is the only place to add a step. A one-time list offers
/// to delete itself once everything is done.
struct StepsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    @Environment(\.glanceNow) private var now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let theme: Theme
    /// Called when the user deletes this list from the Edit sheet; the parent pops back to
    /// the tiles and performs the delete.
    var onDelete: () -> Void = {}

    @State private var showingEdit = false
    @State private var newStepText = ""
    @FocusState private var addFieldFocused: Bool
    /// The step being edited in place (double-tap), and its draft text.
    @State private var editingStepID: UUID?
    @State private var editText = ""
    @FocusState private var editFieldFocused: Bool
    @State private var offeringDelete = false
    /// The dust-and-dots burst after "all done!".
    @State private var celebrating = false

    var body: some View {
        if theme.isDeleted {
            Color.clear   // mid-pop after a delete: never touch a deleted model
        } else {
            content
                .confirmDelete("All done! Delete this list?", isPresented: $offeringDelete,
                               message: "It's a one-time list, so it won't come back.",
                               deleteLabel: "Delete this list", keepLabel: "Keep it", onDelete: onDelete)
        }
    }

    /// The list card, its header and footer, the add row, Edit, and the "all done!" bar.
    private var content: some View {
        List {
            Section {
                let start = theme.currentPeriodStart(now: max(now, Date()))   // once per draw, not per row
                ForEach(theme.orderedSteps) { step in
                    stepRow(step, done: Theme.counts(step.completedAt, since: start))
                        .paperListRow(palette)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) { deleteAction(step) }
                }
                .onMove(perform: moveSteps)   // long-press a row, then drag
                addRow
                    .paperListRow(palette)
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
        .onChange(of: editFieldFocused) { _, focused in
            if !focused { commitEdit() }   // tapping elsewhere saves, like Notes
        }
    }

    // MARK: Rows

    /// One step row: tap to tick, double-tap to edit in place (or the edit field itself).
    /// - Parameters:
    ///   - step: the step to render.
    ///   - done: whether it's ticked this period.
    @ViewBuilder private func stepRow(_ step: Step, done: Bool) -> some View {
        if editingStepID == step.id {
            TextField("Step", text: $editText)
                .characterLimit($editText, TextLimits.step)
                .font(fonts.font(.rowBody))
                .foregroundStyle(palette.ink)
                .focused($editFieldFocused)
                .submitLabel(.done)
                .onSubmit(commitEdit)
                .onAppear { editFieldFocused = true }   // focus once the field exists
                .padding(.vertical, 3)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                stepText(step, done: done)
                    .foregroundStyle(done ? palette.ink2 : palette.ink)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())   // whole row is the tap target, not just the glyphs
            .onTapGesture(count: 2) { beginEdit(step) }   // listed first so it wins over the single tap
            .onTapGesture { toggle(step) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(done ? "done" : "not done")
            .accessibilityHint(done ? "Unchecks this step" : "Checks off this step")
            .accessibilityAction(named: "Edit text") { beginEdit(step) }
            .accessibilityAction(named: "Move up") { move(step, by: -1) }
            .accessibilityAction(named: "Move down") { move(step, by: 1) }
        }
    }

    /// Swipe-left delete, tinted in the board's marker colour rather than system red.
    /// - Parameter step: the row's step.
    private func deleteAction(_ step: Step) -> some View {
        Button(role: .destructive) { delete(step) } label: { Label("Delete", systemImage: "trash") }
            .tint(palette.markerDeep)
    }

    /// The row text: bold lead word, then plain detail. When done: struck through, led by
    /// the same checkmark as the "all done!" swoosh, inline so it wraps with the text.
    /// - Parameters:
    ///   - step: the step to render.
    ///   - done: whether it's ticked this period.
    private func stepText(_ step: Step, done: Bool) -> Text {
        let parts = StepText.split(step.text)
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

    /// The inline "+ write another item" ghost row at the end of the list (a quiet note once
    /// the list holds `CollectionLimits.stepsPerList` steps).
    @ViewBuilder private var addRow: some View {
        if CollectionLimits.hasRoom(theme.steps.count, under: CollectionLimits.stepsPerList) {
            addField
        } else {
            Text("This list is full (\(CollectionLimits.stepsPerList) steps).")
                .font(fonts.font(.caption))
                .foregroundStyle(palette.ink2)
        }
    }

    /// The text field that adds a step.
    private var addField: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .foregroundStyle(palette.marker)
                .accessibilityHidden(true)
            TextField("write another item", text: $newStepText)
                .characterLimit($newStepText, TextLimits.step)
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
        if !theme.steps.isEmpty {
            let done = theme.isListComplete(now: max(now, Date()))
            HStack {
                Spacer()
                Button { setSweep(complete: !done) } label: { SwooshLabel(done: done) }
                    .buttonStyle(.plain)
                    .overlay {
                        if celebrating {
                            DoneBurst {
                                celebrating = false
                                offerDeleteIfOneTimeFinished()   // after the dots, not on top of them
                            }
                        }
                    }
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
        Text(theme.recurrence.resetHint(now: max(now, Date())))
            .font(fonts.font(.caption))
            .foregroundStyle(palette.ink2)
    }

    // MARK: Actions

    /// Ticks or unticks one step.
    private func toggle(_ step: Step) {
        theme.toggle(step)
        save()
        offerDeleteIfOneTimeFinished()
    }

    /// "all done!" (with a burst of marker / chalk dots, unless Reduce Motion is on) /
    /// "bring it back".
    private func setSweep(complete: Bool) {
        theme.setAllDone(complete)
        save()
        if complete && !reduceMotion {
            celebrating = true
        } else {
            offerDeleteIfOneTimeFinished()
        }
    }

    /// A finished one-time list offers to delete itself (it won't come back).
    private func offerDeleteIfOneTimeFinished() {
        offeringDelete = theme.recurrence.kind == .oneTime && theme.isListComplete()
    }

    // MARK: Edit in place, reorder, delete, add

    /// Turns a row into a text field with its text, keyboard up.
    private func beginEdit(_ step: Step) {
        commitEdit()   // finish any other row first
        editText = step.text
        editingStepID = step.id
    }

    /// Saves the edited text (blank keeps the old wording) and turns the row back.
    private func commitEdit() {
        guard let id = editingStepID else { return }
        editingStepID = nil
        if let step = theme.steps.first(where: { $0.id == id }), step.rename(to: editText) { save() }
    }

    /// Deletes one step (swipe left).
    private func delete(_ step: Step) {
        modelContext.delete(step)
        save()
    }

    /// Long-press and drag: rewrites the order to match.
    private func moveSteps(from source: IndexSet, to destination: Int) {
        theme.moveSteps(fromOffsets: source, toOffset: destination)
        save()
    }

    /// VoiceOver's Move up / Move down (dragging's accessible twin).
    private func move(_ step: Step, by offset: Int) {
        if theme.moveStep(step, by: offset) { save() }
    }

    /// Appends the typed step, keeps the field focused for the next one.
    private func addStep() {
        guard theme.addStep(newStepText) != nil else { return }
        newStepText = ""
        addFieldFocused = true
        save()
    }

    /// Saves and rewrites the widget snapshot.
    private func save() {
        try? modelContext.save()
        WidgetDataBridge.refresh(from: modelContext)
    }
}
