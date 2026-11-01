import SwiftUI
import SwiftData

// MARK: - StepsView  (Screen B — the glance view)
/// The list you look at. Native `List` on the paper surface, ~9pt rows, no emoji.
/// Completion follows the theme's style: a whole-list sweep bar, or per-item checkboxes.
struct StepsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts
    let theme: Theme

    @State private var showingEdit = false

    var body: some View {
        List {
            Section {
                ForEach(theme.orderedSteps) { step in
                    stepRow(step)
                        .listRowBackground(palette.card)
                        .listRowSeparatorTint(palette.hairline)
                }
            } footer: {
                footerHint
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) { sweepBar }
        .sheet(isPresented: $showingEdit) { EditThemeView(theme: theme) }
    }

    // MARK: Rows

    /// One step row — optional leading checkbox (per-item), then the step text.
    @ViewBuilder private func stepRow(_ step: Step) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if theme.completionStyle == .perItem {
                checkbox(for: step)
            }
            Text(step.text)
                .font(fonts.font(.rowBody))
                .foregroundStyle(isDone(step) ? palette.ink2 : palette.ink)
                .strikethrough(isDone(step), color: palette.ink2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }

    /// A tappable completion box honoring the daily reset.
    private func checkbox(for step: Step) -> some View {
        Button {
            setStep(step, complete: !isDone(step))
        } label: {
            Image(systemName: isDone(step) ? "checkmark.square.fill" : "square")
                .font(.system(size: 17))
                .foregroundStyle(isDone(step) ? palette.marker : palette.ink2)
        }
        .buttonStyle(.plain)
    }

    // MARK: Sweep bar (whole-list completion)

    @ViewBuilder private var sweepBar: some View {
        if theme.completionStyle == .sweep {
            let done = theme.isListComplete()
            Button { setSweep(complete: !done) } label: {
                Text(done ? "done — tap to bring it back" : "all done!")
                    .font(fonts.font(.button))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(palette.markerDeep)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }

    // MARK: Toolbar + footer

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 8) {
                Image(systemName: ThemeIcons.symbolName(for: theme.iconToken))
                    .foregroundStyle(palette.ink)
                Text(theme.name)
                    .font(fonts.font(.screenTitle))
                    .foregroundStyle(palette.ink)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Edit") { showingEdit = true }
                .foregroundStyle(palette.marker)
        }
    }

    @ViewBuilder private var footerHint: some View {
        Text(theme.completionStyle == .sweep
             ? "Wipes clean and comes back tomorrow."
             : "Tap each box. Nothing is ever “overdue.”")
            .font(fonts.font(.caption))
            .foregroundStyle(palette.ink2)
    }

    // MARK: Completion helpers

    /// Whether a step counts as done right now (false once its calendar day passes).
    private func isDone(_ step: Step) -> Bool {
        CompletionResetPolicy.isStillComplete(completedAt: step.completedAt, now: .now)
    }

    private func setStep(_ step: Step, complete: Bool) {
        step.setComplete(complete)
        try? modelContext.save()
    }

    private func setSweep(complete: Bool) {
        if complete { theme.sweepComplete() } else { theme.resetCompletion() }
        try? modelContext.save()
    }
}
