import Foundation

// MARK: - Temperature Unit
//
// User-selected display unit for body-signal temperatures (wrist
// temperature, in particular). Underlying storage stays in
// Celsius — HealthKit hands us Celsius and the conversion happens
// only at display time so we never lose precision through
// round-trips.

public enum TemperatureUnit: String, CaseIterable, Sendable {
    case celsius
    case fahrenheit

    public var symbol: String {
        switch self {
        case .celsius: "°C"
        case .fahrenheit: "°F"
        }
    }

    public var title: String {
        switch self {
        case .celsius: "Celsius (°C)"
        case .fahrenheit: "Fahrenheit (°F)"
        }
    }

    /// Converts a Celsius-stored value into the user's chosen unit.
    public func display(fromCelsius celsius: Double) -> Double {
        switch self {
        case .celsius: celsius
        case .fahrenheit: celsius * 9.0 / 5.0 + 32.0
        }
    }

    /// Reads the persisted user choice. Defaults to Celsius for
    /// fresh installs (matches the HealthKit-native unit). Reads
    /// UserDefaults directly so non-SwiftUI formatters can call it.
    public static var current: TemperatureUnit {
        let raw = UserDefaults.standard.string(forKey: storageKey)
            ?? TemperatureUnit.celsius.rawValue
        return TemperatureUnit(rawValue: raw) ?? .celsius
    }

    public static let storageKey = "cycle.app.settings.temperatureUnit"
}
