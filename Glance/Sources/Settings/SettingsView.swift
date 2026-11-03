import SwiftUI
import SwiftData

// MARK: - SettingsView  (Screen D: the Settings tab)
/// Appearance, title style, optional features (all off) and data/about, as a native `Form`
/// on the paper surface. Choices persist in `@AppStorage`; ContentView applies them app-wide.
struct SettingsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts

    @AppStorage("glance.appearance") private var appearance: AppAppearance = .system
    @AppStorage(WidgetDataBridge.fontThemeKey, store: WidgetDataBridge.defaults) private var fontThemeID: FontThemeID = FontThemes.default

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                optionalFeaturesSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .paperBackground(palette)
            .paperBars(palette)
            .textCase(nil)   // section labels in sentence case (no ALL CAPS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings").font(fonts.font(.screenTitle)).foregroundStyle(palette.ink)
                }
            }
        }
    }

    // MARK: Sections

    private var appearanceSection: some View {
        Section {
            Picker("Look", selection: $appearance) {
                ForEach(AppAppearance.allCases) { Text($0.label).tag($0) }
            }
            Picker("Title style", selection: $fontThemeID) {
                ForEach(FontThemeID.allCases, id: \.self) { Text(FontThemes.theme($0).displayName).tag($0) }
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Text size follows your iPhone's setting (Settings, Display & Brightness, Text Size).")
        }
        .listRowBackground(palette.card)
    }

    private var optionalFeaturesSection: some View {
        Section {
            plannedToggle("\"You are here\" marker", detail: "Gently highlights your current step.")
            plannedToggle("Gentle reminders", detail: "Optional nudge at a time you choose.")
        } header: {
            Text("Optional features")
        } footer: {
            Text("Planned for a future update. Everything optional is off by default, so nothing will nag you.")
        }
        .listRowBackground(palette.card)
    }

    private var dataSection: some View {
        Section {
            Text("Everything stays private on your device. No developer server sees it.")
                .font(fonts.font(.caption))
                .foregroundStyle(palette.ink2)
        } header: {
            Text("Your data")
        }
        .listRowBackground(palette.card)
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.appVersionString)
        }
        .listRowBackground(palette.card)
    }

    /// A disabled placeholder toggle with a one-line explanation.
    /// - Parameters:
    ///   - title: the feature name.
    ///   - detail: what it would do.
    private func plannedToggle(_ title: String, detail: String) -> some View {
        Toggle(isOn: .constant(false)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(fonts.font(.rowBody)).foregroundStyle(palette.ink)
                Text(detail).font(fonts.font(.caption)).foregroundStyle(palette.ink2)
            }
        }
        .disabled(true)
    }
}

// MARK: - AppAppearance
/// Paper (light), chalkboard (dark), or follow the system.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Match iPhone"
        case .light: return "Paper (light)"
        case .dark: return "Chalkboard (dark)"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Bundle helper
extension Bundle {
    /// "1.0 (1)" style version string for the About row.
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build   = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
