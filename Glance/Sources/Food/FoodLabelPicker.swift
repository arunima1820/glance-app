import SwiftUI

// MARK: - FoodLabelPicker
/// The Food labels page (opened from the form's Food row): tick up to three, the first is the
/// main one (tap a picked label to make it main), search, or add your own. The user's own
/// labels come first, most recent first, then the built-in ones.
struct FoodLabelPicker: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    @Binding var picked: [String]
    /// The user's own labels, most recent first.
    let known: [String]
    /// Called on any change, so the name stops pre-ticking labels.
    let onEdit: () -> Void
    @State private var query = ""

    var body: some View {
        List {
            if !picked.isEmpty { pickedSection }
            Section(query.isEmpty ? "All foods" : "Matches") {
                if let label = addable {
                    Button { toggle(label) } label: {
                        Label { Text(verbatim: "Add \u{201C}\(label)\u{201D}") } icon: { Image(systemName: "plus") }
                    }
                        .disabled(isFull)
                }
                ForEach(shown, id: \.self) { row($0) }
            }
            .paperListRow(palette)
        }
        .scrollContentBackground(.hidden)
        .paperBackground(palette)
        .navigationTitle("Food")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search or add your own")
        .characterLimit($query, FoodLabels.maxLength)
    }

    /// The picked labels, main first.
    private var pickedSection: some View {
        Section {
            ForEach(picked, id: \.self) { label in
                Button { makeMain(label) } label: {
                    HStack {
                        Text(label).foregroundStyle(palette.ink)
                        Spacer()
                        if label == picked.first {
                            Text("main").font(fonts.font(.caption)).foregroundStyle(palette.markerDeep)
                        }
                    }
                }
                .accessibilityHint(label == picked.first ? "The main label" : "Makes this the main label")
            }
            .onDelete { picked.remove(atOffsets: $0); onEdit() }
            .paperListRow(palette)
        } header: {
            Text("Picked (\(picked.count) of \(FoodLabels.maxPicked))")
        } footer: {
            Text("The first one is the main label. Tap one to make it main; swipe to remove.")
        }
    }

    /// One label to tick or untick (greyed out once three are picked).
    private func row(_ label: String) -> some View {
        let isPicked = FoodLabels.contains(picked, label)
        return Button { toggle(label) } label: {
            HStack {
                Text(label).foregroundStyle(palette.ink)
                Spacer()
                if isPicked { Image(systemName: "checkmark").foregroundStyle(palette.marker) }
            }
        }
        .disabled(isFull && !isPicked)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    // MARK: Data

    /// The user's labels, then built-ins they don't already have.
    private var allLabels: [String] {
        known + FoodLabels.builtIn.filter { !FoodLabels.contains(known, $0) }
    }

    /// Labels matching the search (all of them when it's empty).
    private var shown: [String] {
        let term = query.trimmingCharacters(in: .whitespaces)
        return term.isEmpty ? allLabels : allLabels.filter { $0.localizedCaseInsensitiveContains(term) }
    }

    /// What was typed, as a new label, when it isn't one already.
    private var addable: String? {
        guard let label = FoodLabels.normalized(query), !FoodLabels.contains(allLabels, label) else { return nil }
        return label
    }

    /// Three are picked already.
    private var isFull: Bool { picked.count >= FoodLabels.maxPicked }

    /// Picks or unpicks a label (adding stops at three).
    private func toggle(_ label: String) {
        if let index = picked.firstIndex(where: { $0.caseInsensitiveCompare(label) == .orderedSame }) {
            picked.remove(at: index)
        } else if !isFull {
            picked.append(label)
            query = ""
        }
        onEdit()
    }

    /// Moves a picked label to the front.
    private func makeMain(_ label: String) {
        guard let index = picked.firstIndex(of: label), index > 0 else { return }
        picked.insert(picked.remove(at: index), at: 0)
        onEdit()
    }
}
