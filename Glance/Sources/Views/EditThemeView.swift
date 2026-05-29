import SwiftUI
import SwiftData

// MARK: - EditThemeView  (Screen C — create or edit a theme)
/// Add/rename the theme, choose color and icon, manage steps (add/edit/delete/reorder).
/// Shows a gentle note (not a block) when a list reaches 7+ steps.
struct EditThemeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // nil = creating new theme; non-nil = editing existing
    let theme: Theme?

    @State private var name: String = ""
    @State private var colorToken: String = "sage"
    @State private var iconEmoji: String = "⭐️"
    @State private var steps: [DraftStep] = []
    @State private var showingDeleteConfirm = false
    @State private var newStepText: String = ""
    @FocusState private var newStepFocused: Bool

    private var isEditing: Bool { theme != nil }
    private var tooManySteps: Bool { steps.count >= 7 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme name") {
                    TextField("e.g. Take meds", text: $name)
                        .font(GlanceFonts.body)
                        .accessibilityLabel("Theme name")
                }

                Section("Colour") {
                    colorPicker
                }

                Section("Icon (emoji)") {
                    TextField("Emoji", text: $iconEmoji)
                        .font(.system(size: 32))
                        .frame(height: 44)
                        .accessibilityLabel("Theme icon, currently \(iconEmoji)")
                }

                Section {
                    ForEach($steps) { $step in
                        HStack {
                            TextField("Step text", text: $step.text)
                                .font(GlanceFonts.body)
                            Spacer()
                        }
                        .accessibilityLabel("Step: \(step.text)")
                    }
                    .onDelete(perform: deleteSteps)
                    .onMove(perform: moveSteps)

                    // Inline add row
                    HStack {
                        TextField("Add a step…", text: $newStepText)
                            .font(GlanceFonts.body)
                            .focused($newStepFocused)
                            .submitLabel(.done)
                            .onSubmit(commitNewStep)
                        if !newStepText.isEmpty {
                            Button(action: commitNewStep) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(GlanceColors.accent)
                            }
                            .accessibilityLabel("Add step")
                        }
                    }

                    if tooManySteps {
                        Label(
                            "Getting long — consider splitting into two themes.",
                            systemImage: "lightbulb"
                        )
                        .font(GlanceFonts.caption)
                        .foregroundStyle(GlanceColors.secondaryText)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Steps")
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete this theme", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit theme" : "New theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .font(GlanceFonts.label.weight(.semibold))
                }
                ToolbarItem(placement: .keyboard) {
                    EditButton()
                }
            }
            .confirmationDialog(
                "Delete \"\(theme?.name ?? "")\"?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible,
                actions: {
                    Button("Delete", role: .destructive, action: deleteTheme)
                    Button("Cancel", role: .cancel) {}
                },
                message: {
                    Text("This cannot be undone.")
                }
            )
            .onAppear(perform: loadFromTheme)
        }
    }

    // MARK: - Actions

    private func loadFromTheme() {
        guard let theme else { return }
        name = theme.name
        colorToken = theme.colorToken
        iconEmoji = theme.iconEmoji
        steps = theme.orderedSteps.map { DraftStep(id: $0.id, text: $0.text, iconEmoji: $0.iconEmoji) }
    }

    private func commitNewStep() {
        let trimmed = newStepText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        steps.append(DraftStep(text: trimmed))
        newStepText = ""
        newStepFocused = true
    }

    private func deleteSteps(at offsets: IndexSet) {
        steps.remove(atOffsets: offsets)
    }

    private func moveSteps(from source: IndexSet, to destination: Int) {
        steps.move(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        let target: Theme
        if let existing = theme {
            target = existing
        } else {
            target = Theme(name: name, colorToken: colorToken, iconEmoji: iconEmoji)
            modelContext.insert(target)
        }

        target.name = name.trimmingCharacters(in: .whitespaces)
        target.colorToken = colorToken
        target.iconEmoji = iconEmoji
        target.updatedAt = Date()

        // Rebuild steps
        let oldSteps = target.steps
        for old in oldSteps { modelContext.delete(old) }
        target.steps = steps.enumerated().map { idx, draft in
            Step(id: draft.id, text: draft.text, iconEmoji: draft.iconEmoji, sortOrder: idx)
        }

        try? modelContext.save()

        // Refresh widget snapshot
        if let allThemes = try? modelContext.fetch(FetchDescriptor<Theme>()) {
            WidgetDataBridge.writeSnapshot(allThemes.sorted { $0.sortOrder < $1.sortOrder })
        }

        dismiss()
    }

    private func deleteTheme() {
        guard let theme else { return }
        modelContext.delete(theme)
        try? modelContext.save()
        if let allThemes = try? modelContext.fetch(FetchDescriptor<Theme>()) {
            WidgetDataBridge.writeSnapshot(allThemes.sorted { $0.sortOrder < $1.sortOrder })
        }
        dismiss()
    }

    // MARK: - Color picker sub-view

    private var colorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ThemePalette.all) { entry in
                    Button {
                        colorToken = entry.id
                    } label: {
                        Circle()
                            .fill(entry.light)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(GlanceColors.primaryText, lineWidth: colorToken == entry.id ? 3 : 0)
                            )
                    }
                    .accessibilityLabel(entry.displayName + (colorToken == entry.id ? ", selected" : ""))
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - DraftStep (local editing model)
struct DraftStep: Identifiable {
    var id: UUID = UUID()
    var text: String
    var iconEmoji: String?
}
