import SwiftUI

// MARK: - App Theme
//
// User-facing appearance mode. Persisted as a raw string in
// @AppStorage and applied app-wide via .preferredColorScheme(...)
// from AppView. `.system` opts back into the OS-level appearance
// switch and is the default for fresh installs.

public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    /// SwiftUI ColorScheme override. Returning `nil` for `.system`
    /// lets the OS choose, matching how SwiftUI ignores
    /// preferredColorScheme when handed nil.
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

public enum AppThemeStorage {
    public static let key = "cycle.app.settings.theme"
}
