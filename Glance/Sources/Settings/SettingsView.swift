import SwiftUI
import SwiftData

// MARK: - SettingsView  (Screen D: the Settings tab)
/// Appearance, title style, and data/about, as a native `Form`
/// on the paper surface. Choices persist in `@AppStorage`; ContentView applies them app-wide.
struct SettingsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.fonts) private var fonts

    @AppStorage(StorageKeys.appearance) private var appearance: AppAppearance = .system
    @AppStorage(WidgetDataBridge.fontThemeKey, store: WidgetDataBridge.defaults) private var fontThemeID: FontThemeID = FontThemes.default
    @AppStorage(StorageKeys.lockScreenHidesDetails, store: WidgetDataBridge.defaults) private var hideLockScreenDetails = false

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
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

    /// Look (paper / chalkboard / match iPhone) and title style.
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

    /// The privacy promise, and keeping lists off the Lock Screen.
    private var dataSection: some View {
        Section {
            Toggle("Hide details on Lock Screen", isOn: $hideLockScreenDetails)
                .tint(palette.avocado)
                .onChange(of: hideLockScreenDetails) { WidgetDataBridge.reloadWidgets() }
            Text("Everything stays private on your device. No developer server sees it.")
                .font(fonts.font(.caption))
                .foregroundStyle(palette.ink2)
        } header: {
            Text("Your data")
        } footer: {
            Text("When on, the Lock Screen widget shows only how many steps are left, never the list or step names.")
        }
        .listRowBackground(palette.card)
    }

    /// App version.
    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.appVersionString)
        }
        .listRowBackground(palette.card)
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
