import SwiftUI
import SwiftData

// MARK: - SettingsView  (Screen D)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage("glance.appearance") private var appearance: AppAppearance = .system
    @AppStorage("glance.font") private var fontChoice: FontChoice = .system
    @AppStorage("glance.textSizeNote") private var textSizeNoteAcknowledged = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Appearance
                Section("Appearance") {
                    Picker("Colour scheme", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .accessibilityLabel("Colour scheme")

                    Picker("Font", selection: $fontChoice) {
                        ForEach(FontChoice.allCases) { choice in
                            Text(choice.label).tag(choice)
                        }
                    }
                    .accessibilityLabel("Font")

                    Text("Text size follows your iOS system setting (Settings → Display & Brightness → Text Size).")
                        .font(GlanceFonts.caption)
                        .foregroundStyle(GlanceColors.secondaryText)
                }

                // MARK: Optional features (all off by default — v1 placeholder)
                Section {
                    Toggle(isOn: .constant(false)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\"You are here\" marker")
                                .font(GlanceFonts.body)
                            Text("Gently highlights your current step.")
                                .font(GlanceFonts.caption)
                                .foregroundStyle(GlanceColors.secondaryText)
                        }
                    }
                    .disabled(true)

                    Toggle(isOn: .constant(false)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gentle reminders")
                                .font(GlanceFonts.body)
                            Text("Optional nudge at a time you choose.")
                                .font(GlanceFonts.caption)
                                .foregroundStyle(GlanceColors.secondaryText)
                        }
                    }
                    .disabled(true)

                    Text("These optional features are planned for a future update.")
                        .font(GlanceFonts.caption)
                        .foregroundStyle(GlanceColors.secondaryText)
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Optional features")
                } footer: {
                    Text("All optional features are off by default. Nothing will nag you.")
                }

                // MARK: Your data
                Section("Your data") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Everything lives privately in your own iCloud account — not on any developer server. Only you can see it.")
                            .font(GlanceFonts.caption)
                            .foregroundStyle(GlanceColors.secondaryText)
                    }
                    .listRowBackground(Color.clear)

                    Button("Export backup…", action: exportBackup)
                        .font(GlanceFonts.body)
                }

                // MARK: About
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.appVersionString)
                    Link("Help & feedback", destination: URL(string: "https://example.com")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .preferredColorScheme(appearance.colorScheme)
        }
    }

    private func exportBackup() {
        // TODO: Serialize themes to JSON and present share sheet
    }
}

// MARK: - Supporting enums

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark, highContrast
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System default"
        case .light: return "Light"
        case .dark: return "Dark"
        case .highContrast: return "High contrast"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark, .highContrast: return .dark
        }
    }
}

enum FontChoice: String, CaseIterable, Identifiable {
    case system, atkinsonHyperlegible, lexend
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System (San Francisco)"
        case .atkinsonHyperlegible: return "Atkinson Hyperlegible"
        case .lexend: return "Lexend"
        }
    }
}

// MARK: - Bundle helper
extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build   = infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
