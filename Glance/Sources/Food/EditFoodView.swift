import SwiftUI
import SwiftData

// MARK: - EditFoodView
/// Create or edit a food. Required: name, where it lives (defaults to Fridge) and a date
/// (always filled in with a typical time; "Best by" for canned). Optional: what kind, Food
/// labels (own page), description. Also a (not yet active) gentle reminder. Native `Form` half-sheet.
struct EditFoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    @Query(sort: \FoodItem.updatedAt, order: .reverse) private var allFood: [FoodItem]

    /// nil = adding a new food; non-nil = editing this one.
    let item: FoodItem?
    /// A name to start with (e.g. from "Add chicken" after an empty search).
    var prefilledName = ""
    /// If set, Delete hands off to the parent (which leaves the food screen, then removes it).
    var onDelete: (() -> Void)?

    @State private var draft = FoodDraft()
    @State private var loaded = false
    @State private var showingDeleteConfirm = false

    private var isEditing: Bool { item != nil }
    private var canSave: Bool { !draft.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                whereSection
                kindSection
                labelsSection
                ExpiryEditor(mode: userSet(\.mode), days: userSet(\.days), date: userSet(\.date),
                             isGuess: !draft.expiryTouched, isCanned: draft.isCanned)
                reminderSection
                descriptionSection
                if isEditing { deleteSection }
            }
            .scrollContentBackground(.hidden)
            .paperBackground(palette)
            .navigationTitle(isEditing ? "Edit food" : "New food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmDelete("Delete \u{201C}\(item?.name ?? "")\u{201D}?", isPresented: $showingDeleteConfirm,
                           message: "You can restore it from Recently used up.", onDelete: deleteItem)
            .onAppear(perform: load)
            .onChange(of: draft.name) { _, name in draft.suggestLabels(forName: name, among: knownLabels) }
            .onChange(of: draft.place) { draft.suggestExpiry() }
            .onChange(of: draft.kinds) { draft.suggestExpiry() }
            .onChange(of: draft.labels) { draft.suggestExpiry() }
        }
        .presentationDetents([.medium, .large])
        .tint(palette.markerDeep)   // small text (tab labels, Cancel) needs 4.5:1
    }

    // MARK: Sections

    /// The food's name (its words pre-tick Food labels).
    private var nameSection: some View {
        Section("Name") {
            TextField("e.g. Chicken fried rice", text: $draft.name)
                .characterLimit($draft.name, TextLimits.name)
                .font(fonts.font(.rowBody))
        }
        .listRowBackground(palette.card)
    }

    /// Fridge / Freezer / Pantry: one choice.
    private var whereSection: some View {
        Section("Where") {
            Picker("Where", selection: $draft.place) {
                ForEach(FoodStorage.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .listRowBackground(palette.card)
    }

    /// What kind: several allowed.
    private var kindSection: some View {
        Section("What kind") {
            ChipRow(titles: FoodKind.allCases.map(\.label),
                    isOn: { title in draft.kinds.contains { $0.label == title } },
                    onTap: { title in draft.toggleKind(titled: title) })
                .padding(.vertical, Metrics.xs)
        }
        .listRowBackground(palette.card)
    }

    /// The Food row; opens the label picker page.
    private var labelsSection: some View {
        Section {
            NavigationLink {
                FoodLabelPicker(picked: $draft.labels, known: knownLabels, onEdit: { draft.labelsTouched = true })
            } label: {
                LabeledContent("Food", value: draft.labels.isEmpty ? "None" : draft.labels.joined(separator: ", "))
            }
        } footer: {
            Text("Up to \(FoodLabels.maxPicked). The first one shows on the tile.")
        }
        .listRowBackground(palette.card)
    }

    /// Optional description, with the coming-soon note under it.
    private var descriptionSection: some View {
        Section {
            TextField("e.g. Cooked Sunday, in the blue tub", text: $draft.details, axis: .vertical)
                .characterLimit($draft.details, TextLimits.note)
                .font(fonts.font(.rowBody))
                .lineLimit(2...5)
        } header: {
            Text("Description (optional)")
        } footer: {
            Text("More is on the way: snap a photo to add food, and easy meal ideas for things that need using up. For now, you're already ahead just by writing it down.")
                .padding(.top, Metrics.s)
        }
        .listRowBackground(palette.card)
    }

    /// A gentle nudge before it expires: shown greyed out until reminders are built.
    private var reminderSection: some View {
        Section {
            PlannedToggle(title: "Gentle reminder", detail: "A soft nudge before it needs using up. Coming later.")
        }
        .listRowBackground(palette.card)
    }

    /// Delete (editing only).
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) { showingDeleteConfirm = true } label: {
                Label("Delete this food", systemImage: "trash")
            }
        }
        .listRowBackground(palette.card)
    }

    /// Cancel / Save (Save in the marker-swoosh style; no Liquid Glass halo, as on lists).
    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        .withoutSharedGlass()
        ToolbarItem(placement: .confirmationAction) {
            Button(action: save) { MarkerSwooshLabel(title: "Save", quiet: !canSave) }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .accessibilityLabel("Save")
        }
        .withoutSharedGlass()
    }

    // MARK: Actions

    /// A binding for an Expires control that also marks Expires as set by the user, so the
    /// food's type stops changing it.
    /// - Parameter keyPath: the draft field.
    private func userSet<Value>(_ keyPath: WritableKeyPath<FoodDraft, Value>) -> Binding<Value> {
        Binding(get: { draft[keyPath: keyPath] },
                set: { draft[keyPath: keyPath] = $0; draft.expiryTouched = true })
    }

    /// The user's own labels, most recently used first (built-ins are added by the picker).
    private var knownLabels: [String] {
        var seen: [String] = []
        for label in allFood.flatMap(\.labels) where !FoodLabels.contains(seen, label) {
            seen.append(label)
        }
        return seen
    }

    /// Fills the draft once (onAppear can fire again after the keyboard shows).
    private func load() {
        guard !loaded else { return }
        loaded = true
        if let item {
            draft = FoodDraft(editing: item)
        } else if !prefilledName.isEmpty {
            draft.name = prefilledName
        }
    }

    /// Writes the draft back, refreshes the widgets, closes the sheet.
    private func save() {
        guard let target = item ?? insertNew() else { dismiss(); return }   // kitchen full
        draft.apply(to: target)
        try? modelContext.save()
        WidgetDataBridge.refreshFood(from: modelContext)
        dismiss()
    }

    /// Adds a new, empty food to the store for Save to fill in, or nil if it's full.
    private func insertNew() -> FoodItem? {
        let count = (try? modelContext.fetchCount(FetchDescriptor<FoodItem>())) ?? 0
        guard CollectionLimits.hasRoom(count, under: CollectionLimits.foods) else { return nil }
        let created = FoodItem(name: draft.name)
        modelContext.insert(created)
        return created
    }

    /// Delete: the food screen removes it (with Undo), or, with no screen behind, it's removed
    /// here and kept in Recently used up.
    private func deleteItem() {
        guard let item else { return }
        dismiss()
        if let onDelete {
            onDelete()
        } else {
            RecentlyRemoved<FoodSnapshot>.food().add(item.snapshot)
            modelContext.delete(item)
            try? modelContext.save()
            WidgetDataBridge.refreshFood(from: modelContext)
        }
    }
}

// MARK: - ExpiryEditor
/// "Expires": one menu row ("In a few days" / "On a date"); the row under it is a days
/// stepper (days, then weeks, then months) or a date picker. Like a list's "Resets" row.
struct ExpiryEditor: View {
    @Environment(\.palette) private var palette
    @Binding var mode: ExpiryMode
    @Binding var days: Int
    @Binding var date: Date
    /// The days came from the food's type, not the user: say it's a starting guess.
    var isGuess = false
    /// Canned: the row is a "Best by" reminder rather than a use-by date.
    var isCanned = false

    var body: some View {
        Section {
            Picker("Expires", selection: $mode) {
                ForEach(ExpiryMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            switch mode {
            case .inDays:
                Stepper(FoodExpiry.daysLabel(days), onIncrement: increment, onDecrement: decrement)
            case .onDate:
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
        } header: {
            Text(isCanned ? "Best by" : "Expires")
        } footer: {
            footer
        }
        .listRowBackground(palette.card)
    }

    /// The note under the row: what the starting date means.
    @ViewBuilder private var footer: some View {
        if isCanned {
            Text("Unopened cans keep a long time. This is just a reminder to check the date on the can.")
        } else if isGuess && mode == .inDays {
            Text("A starting point from US food-safety charts. Change it any time. When in doubt, throw it out.")
        }
    }

    /// Up one stop (days → weeks → months); nil at the top, which disables "+".
    private var increment: (() -> Void)? {
        guard let next = FoodExpiry.step(after: days) else { return nil }
        return { days = next }
    }

    /// Down one stop; nil at "Today", which disables "−".
    private var decrement: (() -> Void)? {
        guard let previous = FoodExpiry.step(before: days) else { return nil }
        return { days = previous }
    }
}
