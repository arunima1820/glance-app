import SwiftUI
import SwiftData

// MARK: - ThemesView  (Screen A — home of the app)
/// Grid/list of all themes. Tapping a theme opens StepsView (Screen B).
struct ThemesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Theme.sortOrder) private var themes: [Theme]

    @State private var showingAddTheme = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                GlanceColors.background.ignoresSafeArea()

                if themes.isEmpty {
                    emptyState
                } else {
                    themeGrid
                }

                addButton
            }
            .navigationTitle("Glance")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .accessibilityLabel("Settings")
                    }
                }
            }
            .sheet(isPresented: $showingAddTheme) {
                EditThemeView(theme: nil)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onAppear(perform: seedIfNeeded)
        }
    }

    // MARK: - Sub-views

    private var themeGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                spacing: 16
            ) {
                ForEach(themes) { theme in
                    NavigationLink(destination: StepsView(theme: theme)) {
                        ThemeCardView(theme: theme)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .padding(.bottom, 100) // clear the floating add button
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("No themes yet")
                .font(GlanceFonts.title)
                .foregroundStyle(GlanceColors.primaryText)
            Text("Tap + to add your first theme.")
                .font(GlanceFonts.body)
                .foregroundStyle(GlanceColors.secondaryText)
        }
        .multilineTextAlignment(.center)
    }

    private var addButton: some View {
        Button {
            showingAddTheme = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(GlanceColors.accent)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .accessibilityLabel("New theme")
        .padding(24)
    }

    // MARK: - Helpers

    private func seedIfNeeded() {
        guard themes.isEmpty else { return }
        let starters = StarterTemplates.all()
        for theme in starters {
            modelContext.insert(theme)
        }
        try? modelContext.save()
        WidgetDataBridge.writeSnapshot(starters)
    }
}

// MARK: - ThemeCardView
struct ThemeCardView: View {
    let theme: Theme

    private var palette: ThemePalette.Entry { ThemePalette.entry(for: theme.colorToken) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(theme.iconEmoji)
                .font(.system(size: 36))
                .accessibilityHidden(true)

            Text(theme.name)
                .font(GlanceFonts.label)
                .foregroundStyle(GlanceColors.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text("\(theme.steps.count) step\(theme.steps.count == 1 ? "" : "s")")
                .font(GlanceFonts.caption)
                .foregroundStyle(GlanceColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(palette.light)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(theme.iconEmoji) \(theme.name), \(theme.steps.count) steps")
        .accessibilityHint("Opens this theme's steps")
    }
}
