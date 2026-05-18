import Foundation

// MARK: - App Language
//
// Maps the eight US-priority locales declared in
// `Info.plist → CFBundleLocalizations` onto a typed enum used by
// LanguagePickerView. Each case knows its BCP-47 code, its
// English display name, and its native autonym so the picker
// can render rows the user recognises in their own script.

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english     = "en"
    case spanish     = "es"
    case chineseSimplified  = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case vietnamese  = "vi"
    case tagalog     = "tl"
    case korean      = "ko"
    case french      = "fr"

    public var id: String { rawValue }

    /// Display name in English — what users browsing the picker
    /// in their current language read as the "outer" label.
    public var englishName: String {
        switch self {
        case .english:             "English"
        case .spanish:             "Spanish"
        case .chineseSimplified:   "Chinese (Simplified)"
        case .chineseTraditional:  "Chinese (Traditional)"
        case .vietnamese:          "Vietnamese"
        case .tagalog:             "Tagalog"
        case .korean:              "Korean"
        case .french:              "French"
        }
    }

    /// Autonym — the name of the language *in* that language.
    /// Picker rows show this in the row's trailing slot so
    /// speakers find their own language without depending on
    /// the current app locale.
    public var autonym: String {
        switch self {
        case .english:             "English"
        case .spanish:             "Español"
        case .chineseSimplified:   "简体中文"
        case .chineseTraditional:  "繁體中文"
        case .vietnamese:          "Tiếng Việt"
        case .tagalog:             "Tagalog"
        case .korean:              "한국어"
        case .french:              "Français"
        }
    }
}

public enum AppLanguageStorage {
    /// The system-reserved UserDefaults key iOS reads on launch
    /// to decide which language to use for this app's bundle.
    /// Writing `["es"]` here pins the app to Spanish regardless
    /// of the device-wide language setting.
    public static let appleLanguagesKey = "AppleLanguages"

    /// Reads the active override (if any) from UserDefaults.
    /// Returns `nil` when the user hasn't explicitly picked —
    /// meaning the app should fall back to the system language.
    public static var currentOverride: AppLanguage? {
        guard let codes = UserDefaults.standard.array(forKey: appleLanguagesKey) as? [String],
              let primary = codes.first else { return nil }
        return AppLanguage.allCases.first { primary.hasPrefix($0.rawValue) }
    }

    /// Persists an override. Pass `nil` to clear and revert to
    /// the system locale. The change only takes effect after the
    /// app process restarts — iOS doesn't hot-swap the bundle's
    /// localization tables.
    public static func setOverride(_ language: AppLanguage?) {
        if let language {
            UserDefaults.standard.set([language.rawValue], forKey: appleLanguagesKey)
        } else {
            UserDefaults.standard.removeObject(forKey: appleLanguagesKey)
        }
    }
}
