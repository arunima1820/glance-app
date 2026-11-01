import SwiftUI
import SwiftData

// MARK: - EditThemeView  (Screen C: create or edit a list)
/// A list's settings only: name, icon, colour, repeats, and delete. Steps live in the list itself
/// (add with the inline row, swipe to delete). Native `Form` half-sheet.
struct EditThemeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    @EnvironmentObject private var design: DesignConfig

    /// nil = creating a new list; non-nil = editing this one.
    let theme: Theme?
    /// If set, Delete hands off to the parent (which leaves the list screen, then deletes).
    var onDelete: (() -> Void)?

    @State private var name = ""
    @State private var colorToken = "sage"
    @State private var iconToken = ThemeIcons.default
    @State private var completionStyle = ThemeCompletionStyle.sweep
    @State private var recurrence = Recurrence()
    @State private var showingDeleteConfirm = false
    @State private var loaded = false

    private var isEditing: Bool { theme != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                iconSection
                colorSection
                RepeatEditor(rule: $recurrence)
                if isEditing { deleteSection }
            }
            .scrollContentBackground(.hidden)
            .paperBackground(palette)
            .navigationTitle(isEditing ? "Edit list" : "New list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmationDialog("Delete \"\(theme?.name ?? "")\"?", isPresented: $showingDeleteConfirm,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: deleteTheme)
                Button("Cancel", role: .cancel) {}
            } message: { Text("This cannot be undone.") }
            .onAppear(perform: loadFromTheme)
        }
        .presentationDetents([.medium, .large])
        .tint(palette.marker)
    }

    // MARK: Sections

    private var nameSection: some View {
        Section("Name") {
            TextField("e.g. Take meds", text: $name)
                .font(fonts.font(.rowBody))
                .listRowBackground(palette.card)
        }
    }

    private var iconSection: some View {
        Section("Icon") {
            IconPicker(selection: $iconToken)
                .listRowBackground(palette.card)
        }
    }

    private var colorSection: some View {
        Section("Colour") {
            ColorTokenPicker(selection: $colorToken)
                .listRowBackground(palette.card)
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) { showingDeleteConfirm = true } label: {
                Label("Delete this list", systemImage: "trash")
            }
            .listRowBackground(palette.card)
        }
    }

    /// Cancel / Save. On iOS 26 the system draws a Liquid Glass capsule behind toolbar items
    /// once the sheet is dragged to full height (a "halo" the half sheet doesn't show);
    /// hiding that shared background keeps the buttons looking the same at every height.
    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        if #available(iOS 26.0, *) {
            cancelItem.sharedBackgroundVisibility(.hidden)
            saveItem.sharedBackgroundVisibility(.hidden)
        } else {
            cancelItem
            saveItem
        }
    }

    private var cancelItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
    }

    private var saveItem: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(action: save) { MarkerSwooshLabel(title: "Save", quiet: !canSave) }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .accessibilityLabel("Save")
        }
    }

    // MARK: Actions

    /// Fills the draft from the theme once (onAppear can fire again after the keyboard shows).
    private func loadFromTheme() {
        guard !loaded else { return }
        loaded = true
        guard let theme else {
            completionStyle = design.flags.defaultCompletionStyle
            return
        }
        name = theme.name
        colorToken = theme.colorToken
        iconToken = theme.iconToken
        completionStyle = theme.completionStyle
        recurrence = theme.recurrence
    }

    /// Writes the settings back (steps are never touched here), then refreshes the widget.
    private func save() {
        let target = theme ?? insertNewTheme()
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.colorToken = colorToken
        target.iconToken = iconToken
        target.completionStyle = completionStyle
        target.recurrence = recurrence
        target.updatedAt = .now
        try? modelContext.save()
        WidgetDataBridge.refresh(from: modelContext)
        dismiss()
    }

    private func insertNewTheme() -> Theme {
        let nextOrder = ((try? modelContext.fetch(FetchDescriptor<Theme>()))?.map(\.sortOrder).max() ?? -1) + 1
        let created = Theme(name: name, sortOrder: nextOrder)
        modelContext.insert(created)
        return created
    }

    private func deleteTheme() {
        guard let theme else { return }
        if let onDelete {
            dismiss()
            onDelete()
            return
        }
        modelContext.delete(theme)
        try? modelContext.save()
        WidgetDataBridge.refresh(from: modelContext)
        dismiss()
    }
}

// MARK: - IconPicker
/// Grid of the theme icon set (SF Symbols); the selected one is ringed in marker.
struct IconPicker: View {
    @Environment(\.palette) private var palette
    @Binding var selection: String

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
            ForEach(ThemeIcons.all) { icon in
                let selected = icon.id == selection
                Button { selection = icon.id } label: {
                    Image(systemName: icon.systemName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selected ? palette.marker : palette.ink)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(selected ? palette.marker : palette.hairline, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(icon.displayName + (selected ? ", selected" : ""))
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - ColorTokenPicker
/// Row of theme colors; color is paired with its name for VoiceOver.
struct ColorTokenPicker: View {
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ThemePalette.all) { entry in
                    let selected = entry.id == selection
                    Button { selection = entry.id } label: {
                        Circle()
                            .fill(scheme == .dark ? entry.dark : entry.light)
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(palette.ink, lineWidth: selected ? 2.5 : 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(entry.displayName + (selected ? ", selected" : ""))
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - RepeatEditor
/// "Repeats" section (design option B): lists repeat by default; a switch makes a one-time
/// list. One "Resets" menu row holds the simple choices; weekly / monthly / every-few-days
/// show one small extra control underneath.
struct RepeatEditor: View {
    @Environment(\.palette) private var palette
    @Binding var rule: Recurrence
    /// What to go back to when "One-time list" is switched off again.
    @State private var lastRepeating = Recurrence.Kind.daily

    private static let menuKinds: [Recurrence.Kind] = [.daily, .weekdays, .weekends, .weekly, .monthly, .everyNDays]

    var body: some View {
        Section("Repeats") {
            Toggle("One-time list", isOn: oneTime)
                .tint(palette.avocado)
            if rule.kind != .oneTime {
                Picker("Resets", selection: $rule.kind) {
                    ForEach(Self.menuKinds, id: \.self) { Text(Self.menuLabel($0)).tag($0) }
                }
                .pickerStyle(.menu)
                detailRow
            }
        }
        .listRowBackground(palette.card)
        .onChange(of: rule.kind) { _, kind in
            // First time picking weekly: start with today's weekday so it's never empty.
            if kind == .weekly && rule.weekdays.isEmpty {
                rule.weekdays = [Calendar.current.component(.weekday, from: .now)]
            }
        }
    }

    /// The one extra control some choices need.
    @ViewBuilder private var detailRow: some View {
        switch rule.kind {
        case .weekly:
            WeekdayDots(selection: $rule.weekdays)
        case .monthly:
            Stepper("On day \(rule.dayOfMonth)", value: $rule.dayOfMonth, in: 1...31)
        case .everyNDays:
            Stepper("Every \(rule.interval) days", value: $rule.interval, in: 2...30)
        default:
            EmptyView()
        }
    }

    /// The switch flips to `.oneTime` and back to the last repeating choice.
    private var oneTime: Binding<Bool> {
        Binding(
            get: { rule.kind == .oneTime },
            set: { isOn in
                if isOn {
                    lastRepeating = rule.kind
                    rule.kind = .oneTime
                } else {
                    rule.kind = lastRepeating == .oneTime ? .daily : lastRepeating
                }
            }
        )
    }

    /// Menu wording (short; the detail row below does the rest).
    static func menuLabel(_ kind: Recurrence.Kind) -> String {
        switch kind {
        case .daily:      return "Every day"
        case .weekdays:   return "Every weekday"
        case .weekends:   return "Weekends"
        case .weekly:     return "Weekly on…"
        case .monthly:    return "Monthly on…"
        case .everyNDays: return "Every few days…"
        case .oneTime:    return "One time"
        }
    }
}

// MARK: - WeekdayDots
/// Seven tappable day dots (Mon → Sun). Filled = the list resets that day.
/// Always keeps at least one day selected.
struct WeekdayDots: View {
    @Environment(\.palette) private var palette
    @Binding var selection: Set<Int>

    /// Calendar weekday numbers in Monday-first order.
    private static let order = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        HStack {
            ForEach(Self.order, id: \.self) { day in
                let on = selection.contains(day)
                Button { toggle(day) } label: {
                    Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(on ? palette.onMarker : palette.ink2)
                        .frame(width: 32, height: 32)
                        .background(on ? palette.markerDeep : Color.clear, in: Circle())
                        .overlay(Circle().stroke(on ? Color.clear : palette.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
                if day != 1 { Spacer(minLength: 0) }
            }
        }
        .padding(.vertical, 4)
    }

    private func toggle(_ day: Int) {
        if selection.contains(day) {
            if selection.count > 1 { selection.remove(day) }
        } else {
            selection.insert(day)
        }
    }
}

