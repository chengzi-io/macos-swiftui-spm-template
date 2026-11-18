import Foundation
import Platform
import SwiftUI

/// The General tab: appearance, language, and the Updates section.
struct GeneralSettingsView: View {
    @Bindable var model: SettingsModel
    /// `CFBundleShortVersionString (CFBundleVersion)`, which scripts/build-app.sh writes.
    let version: String
    @Environment(\.openURL) private var openURL

    init(model: SettingsModel, version: String = Self.bundleVersion) {
        self.model = model
        self.version = version
    }

    var body: some View {
        Form {
            Section {
                Picker(selection: $model.appearance) {
                    ForEach(Appearance.allCases, id: \.self) { appearance in
                        Self.name(of: appearance).tag(appearance)
                    }
                } label: {
                    Text("Appearance", bundle: .module)
                }
                LabeledContent {
                    HStack {
                        Text(verbatim: model.languageName)
                            .foregroundStyle(.secondary)
                        Button {
                            openLanguageSettings()
                        } label: {
                            Text("Change…", bundle: .module)
                        }
                    }
                } label: {
                    Text("Language", bundle: .module)
                }
            }
            Section {
                LabeledContent {
                    HStack {
                        Text(verbatim: version)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        CheckForUpdatesButton(updater: model.updater)
                    }
                } label: {
                    Text("Version", bundle: .module)
                }
                Toggle(
                    isOn: Binding(
                        get: { model.updater.automaticallyChecksForUpdates },
                        set: { model.updater.automaticallyChecksForUpdates = $0 }
                    )
                ) {
                    Text("Automatically check for updates", bundle: .module)
                }
            } header: {
                Text("Updates", bundle: .module)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private static func name(of appearance: Appearance) -> Text {
        switch appearance {
        case .system: Text("System", bundle: .module)
        case .light: Text("Light", bundle: .module)
        case .dark: Text("Dark", bundle: .module)
        }
    }

    /// The app's own row in Language & Region › Applications: macOS switches an app's
    /// language there (from the languages `CFBundleLocalizations` lists) and relaunches it.
    private func openLanguageSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension")
        else { return }
        openURL(url)
    }

    private static var bundleVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info["CFBundleVersion"] as? String ?? "unknown"
        return "\(version) (\(build))"
    }
}

#Preview {
    GeneralSettingsView(
        model: SettingsModel(
            updater: MockUpdaterService(),
            preferences: MockPreferencesStore(),
            appearance: MockAppearanceService()
        ),
        version: "1.2.0 (345)"
    )
}
