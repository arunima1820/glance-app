import SwiftUI

// MARK: - RemovedRow
/// One line in "Recently removed", ready to draw.
struct RemovedRow: Identifiable, Hashable {
    let id: UUID
    let title: String
    /// Quiet detail, e.g. "Prepared · Chicken" or "3 steps".
    let detail: String
    let removedAt: Date
    /// What the preview lists (a food's description, or a list's steps).
    let previewLines: [String]
}

// MARK: - RecentlyRemovedLink
/// A quiet one-line text link pinned bottom-left, just above the tab bar ("Recently used up · 3 ›"),
/// shown only when something's there. It never moves as tiles come and go. Tapping it slides
/// up the sheet.
struct RecentlyRemovedLink: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    let title: String
    let count: Int
    let action: () -> Void

    var body: some View {
        if count > 0 {
            Button(action: action) {
                Text("\(title) · \(count) \u{203A}")
                    .font(fonts.font(.caption))
                    .foregroundStyle(palette.markerDeep)   // small text: 4.5:1
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Metrics.l)
            .background(palette.paper)   // tiles scroll under it; keep the text readable
            .accessibilityLabel("\(title), \(count)")
            .accessibilityHint("Shows the last few you removed, to look at or restore")
        }
    }
}

// MARK: - RecentlyRemovedSheet
/// The last five removed lists or foods, in a sheet that slides up (half height, drag for
/// full, swipe down to close). Tap a row to look at it; Restore brings it back; Clear forgets
/// them all (after a confirm).
struct RecentlyRemovedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    let title: String
    let rows: [RemovedRow]
    let onRestore: (UUID) -> Void
    /// Forgets every kept copy.
    let onClear: () -> Void
    @State private var confirmingClear = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(rows) { row in
                        NavigationLink(value: row) { line(row) }
                    }
                    .paperListRow(palette)
                } footer: {
                    Text("The last \(RecentlyRemoved<FoodSnapshot>.limit) are kept; older ones drop off.")
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground(palette)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: RemovedRow.self) { row in
                RemovedPreview(row: row) { restore(row.id) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear", role: .destructive) { confirmingClear = true }
                        .disabled(rows.isEmpty)
                }
            }
            .confirmDelete("Clear \(title)?", isPresented: $confirmingClear,
                           message: "These copies are gone for good after this.", deleteLabel: "Clear") {
                onClear()
                dismiss()
            }
            .overlay { if rows.isEmpty { emptyNote } }
        }
        .presentationDetents([.medium, .large])
        .tint(palette.markerDeep)
    }

    /// One removed item: name, then detail and when.
    private func line(_ row: RemovedRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.title).font(fonts.font(.rowBody)).foregroundStyle(palette.ink).lineLimit(1)
            (Text(row.detail.isEmpty ? "" : row.detail + " · ")
                + Text(row.removedAt, format: .relative(presentation: .named)))
                .font(fonts.font(.caption))
                .foregroundStyle(palette.ink2)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button { restore(row.id) } label: { Label("Restore", systemImage: "arrow.uturn.backward") }
                .tint(palette.avocado)
        }
    }

    /// Shown once everything has been restored.
    private var emptyNote: some View {
        Text("Nothing here right now.")
            .font(fonts.font(.rowBody))
            .foregroundStyle(palette.ink2)
    }

    /// Restores one item and closes the sheet (it's back on the board).
    private func restore(_ id: UUID) {
        onRestore(id)
        dismiss()
    }
}

// MARK: - RemovedPreview
/// A quick look at something removed (pushed inside the sheet), with Restore.
struct RemovedPreview: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    let row: RemovedRow
    let onRestore: () -> Void

    var body: some View {
        List {
            Section {
                if row.previewLines.isEmpty {
                    Text("Nothing else was written down.").foregroundStyle(palette.ink2).paperListRow(palette)
                }
                ForEach(Array(row.previewLines.enumerated()), id: \.offset) { _, text in
                    Text(text).font(fonts.font(.rowBody)).foregroundStyle(palette.ink)
                }
                .paperListRow(palette)
            } header: {
                Text(row.title).font(fonts.font(.listTitle)).foregroundStyle(palette.ink2).textCase(nil)
            } footer: {
                Text(row.detail).font(fonts.font(.caption))
            }
        }
        .scrollContentBackground(.hidden)
        .paperBackground(palette)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: onRestore) { MarkerSwooshLabel(title: "Restore") }
                    .buttonStyle(.plain)
            }
            .withoutSharedGlass()
        }
    }
}

// MARK: - UndoBar
/// A short-lived bar after something is removed: "Oat milk used up · Undo".
/// It slides up (or just fades in with Reduce Motion on), and offers Dismiss to VoiceOver,
/// which keeps it on screen until then.
struct UndoBar: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let message: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Text(message).font(fonts.font(.rowBody)).foregroundStyle(palette.ink).lineLimit(1)
            Spacer(minLength: Metrics.s)
            Button("Undo", action: onUndo)
                .font(fonts.font(.button))
                .foregroundStyle(palette.marker)
        }
        .padding(.horizontal, Metrics.l)
        .padding(.vertical, Metrics.m)
        .paperCard(palette)
        .padding(.horizontal, Metrics.l)
        .padding(.bottom, Metrics.s)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Dismiss", onDismiss)
    }
}
