import SwiftUI

/// Settings panel surfaced from the symptom sheet's bottom bar.
/// Holds personalization toggles for symptom logging — For-you
/// tab visibility, future tracker preferences, etc.
///
/// Built on `AppSheetScreen` so the chrome (close button, header
/// typography, AppleHealthBackground) is identical to the parent
/// symptom sheet — the user perceives one continuous design
/// language rather than two unrelated screens.
///
/// Persistence: settings are bound through `@AppStorage` so
/// they survive across launches without needing reducer state.
/// `SymptomSettingsKeys` exposes the same keys to other surfaces
/// (the sheet itself reads `forYouTabEnabled` to decide whether
/// to show the For-you tab).
struct SymptomSettingsView: View {
    let onClose: () -> Void

    @AppStorage(SymptomSettingsKeys.forYouTabEnabled)
    private var forYouTabEnabled: Bool = true

    var body: some View {
        AppSheetScreen(
            title: "Symptom settings",
            onClose: onClose
        ) {
            VStack(spacing: 12) {
                SymptomSettingsRow(
                    icon: "lightbulb",
                    title: "For you tab",
                    subtitle: "Show a personalised tab tuned to your cycle phase",
                    trailing: .toggle($forYouTabEnabled)
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
    }
}

/// Centralised UserDefaults keys for symptom-sheet preferences.
/// Keep all symptom-related defaults here so the keys live in
/// one place — adding a new toggle means adding one constant
/// here and one row in `SymptomSettingsView`.
enum SymptomSettingsKeys {
    /// Whether the For-you tab appears in the category bar.
    /// Default: true. Stored as `Bool` in UserDefaults.
    static let forYouTabEnabled = "cycle.app.symptom.forYouTabEnabled"
}
