import SwiftUI
import SwiftData

// MARK: - FoodDetailView
/// One food, opened: its description where a list's steps would be, then the details, and
/// "used it up!" at the bottom (which removes it, with Undo). Edit opens the form sheet.
struct FoodDetailView: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    @Environment(\.glanceNow) private var now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: FoodItem
    /// "used it up!": the parent pops back to the tiles and removes it.
    var onUsedUp: () -> Void = {}
    /// Delete from the Edit sheet: the parent pops back and removes it.
    var onDelete: () -> Void = {}
    @State private var showingEdit = false
    /// The duster is wiping the food away after "used it up!".
    @State private var wiping = false

    var body: some View {
        if item.isDeleted {
            Color.clear   // mid-pop after a removal: never touch a deleted model
        } else {
            content
        }
    }

    /// Description card, details card, Edit, and the "used it up!" bar.
    private var content: some View {
        List {
            Section {
                descriptionRow.paperListRow(palette)
            } header: {
                header
            }
            Section("Details") {
                Group { detailRows }.paperListRow(palette)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .paperBars(palette)
        .safeAreaInset(edge: .bottom) { usedUpBar }
        .overlay {
            if wiping { DusterWipe(onFinish: onUsedUp) }
        }
        .sheet(isPresented: $showingEdit) { EditFoodView(item: item, onDelete: onDelete) }
    }

    /// The food's name, just above its card (like a list's name on its screen).
    private var header: some View {
        HStack(spacing: Metrics.s) {
            Image(systemName: item.place.symbol).accessibilityHidden(true)
            Text(item.name)
        }
        .font(fonts.font(.listTitle))
        .foregroundStyle(palette.ink2)
        .textCase(nil)
        .padding(.bottom, Metrics.xs)
        .accessibilityAddTraits(.isHeader)
    }

    /// The description, or a quiet hint when there isn't one.
    @ViewBuilder private var descriptionRow: some View {
        if item.details.isEmpty {
            Text("No description. Tap Edit to add one.")
                .font(fonts.font(.rowBody))
                .foregroundStyle(palette.ink2)
        } else {
            Text(item.details)
                .font(fonts.font(.rowBody))
                .foregroundStyle(palette.ink)
        }
    }

    /// Expires, where, what kind, Food labels, and when it was added.
    @ViewBuilder private var detailRows: some View {
        LabeledContent(item.isCanned ? "Best by" : "Expires") { expiryValue }
        LabeledContent("Where", value: item.place.label)
        if !item.kinds.isEmpty {
            LabeledContent("What kind", value: item.kinds.map(\.label).joined(separator: ", "))
        }
        if !item.labels.isEmpty {
            LabeledContent("Food", value: item.labels.joined(separator: ", "))
        }
        LabeledContent("Added") { Text(item.addedAt, format: .dateTime.weekday(.abbreviated).month().day()) }
    }

    /// "Thu, Nov 5" plus its pill ("No date yet" only for foods from early builds).
    @ViewBuilder private var expiryValue: some View {
        if let useBy = item.snapshot.useBy {
            HStack(spacing: Metrics.s) {
                Text(useBy, format: .dateTime.weekday(.abbreviated).month().day())
                FreshnessPill(freshness: FoodQuery.pill(for: item.snapshot, now: max(now, Date())), palette: palette)
            }
        } else {
            Text("No date yet. Tap Edit to add one.")
        }
    }

    /// The bottom "used it up!" swoosh (like a list's "all done!").
    private var usedUpBar: some View {
        HStack {
            Spacer()
            Button(action: usedUp) { MarkerSwooshLabel(title: "used it up!", showsCheck: true) }
                .buttonStyle(.plain)
                .disabled(wiping)
                .accessibilityHint("Removes it. You can undo or restore it.")
        }
        .padding(.horizontal, Metrics.xl)
        .padding(.vertical, Metrics.m)
        .background(palette.paper)
    }

    /// "used it up!": the duster wipes it away first (unless Reduce Motion is on), then the
    /// parent pops back and removes it.
    private func usedUp() {
        if reduceMotion { onUsedUp() } else { wiping = true }
    }

    /// Edit, in the same marker-swoosh style as "used it up!".
    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingEdit = true } label: { MarkerSwooshLabel(title: "Edit") }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit food")
        }
        .withoutSharedGlass()
    }
}
