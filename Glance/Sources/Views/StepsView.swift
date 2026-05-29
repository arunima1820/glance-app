import SwiftUI
import SwiftData

// MARK: - StepsView  (Screen B — one theme's steps)
/// Pure viewing screen. Nothing to tap on the steps themselves — this is for looking at.
/// The same visual layout mirrors what the widget shows.
struct StepsView: View {
    @Environment(\.modelContext) private var modelContext
    let theme: Theme

    @State private var showingEdit = false

    private var palette: ThemePalette.Entry { ThemePalette.entry(for: theme.colorToken) }

    var body: some View {
        ZStack {
            GlanceColors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Theme header
                    HStack(spacing: 16) {
                        Text(theme.iconEmoji)
                            .font(.system(size: 48))
                            .accessibilityHidden(true)
                        Text(theme.name)
                            .font(GlanceFonts.largeTitle)
                            .foregroundStyle(GlanceColors.primaryText)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                    // Steps list
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(theme.orderedSteps) { step in
                            StepRowView(step: step)
                            if step.id != theme.orderedSteps.last?.id {
                                Divider()
                                    .padding(.leading, 24)
                            }
                        }
                    }
                    .background(GlanceColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
                    .font(GlanceFonts.label)
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditThemeView(theme: theme)
        }
        .accessibilityLabel("\(theme.iconEmoji) \(theme.name)")
    }
}

// MARK: - StepRowView
struct StepRowView: View {
    let step: Step

    var body: some View {
        HStack(spacing: 16) {
            if let icon = step.iconEmoji {
                Text(icon)
                    .font(.system(size: 28))
                    .frame(width: 36)
                    .accessibilityHidden(true)
            } else {
                // Bullet dot to maintain alignment when no icon
                Circle()
                    .fill(GlanceColors.bulletDot)
                    .frame(width: 8, height: 8)
                    .frame(width: 36)
                    .accessibilityHidden(true)
            }

            Text(step.text)
                .font(GlanceFonts.stepText)
                .foregroundStyle(GlanceColors.primaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .contentShape(Rectangle()) // full-row tap area for accessibility
        .accessibilityLabel(step.iconEmoji.map { "\($0) \(step.text)" } ?? step.text)
    }
}
