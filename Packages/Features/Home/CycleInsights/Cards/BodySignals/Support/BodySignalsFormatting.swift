import Foundation
import SwiftUI

// MARK: - Body Signals Formatting
//
// Pure value-formatting + symbol helpers used by every surface the
// feature renders (the teaser card rows, the detail sheet subtitles,
// the accessibility labels). Kept metric-aware so each type shows the
// right precision and unit without caller-side if/else ladders.

/// Format the latest numeric reading for a metric. Wrist temp uses
/// one decimal, HRV/RHR round to whole numbers — matches how Apple
/// Health displays the same values.
func formattedBodySignalValue(
    _ value: Double,
    unit: String,
    kind: BodySignalMetric.Kind
) -> String {
    switch kind {
    case .wristTemperature:
        // Underlying storage is Celsius. Convert + reskin the
        // unit string per the user's Settings → Units pick at the
        // moment of display so the underlying SwiftData stays
        // canonical.
        let temp = TemperatureUnit.current
        let converted = temp.display(fromCelsius: value)
        return String(format: "%.1f%@", converted, temp.symbol)
    case .hrv:
        return String(format: "%.0f %@", value, unit)
    case .restingHR:
        return String(format: "%.0f %@", value, unit)
    }
}

/// Per-metric formatter for deltas (e.g. "+0.18°C", "− 3 bpm"). Keeps
/// the flat-threshold knob with the formatter so the teaser's "in
/// line with" detection stays unit-aware.
struct BodySignalDeltaFormatter {
    let flatThreshold: Double
    let format: (Double) -> String
}

func bodySignalDeltaFormatter(for kind: BodySignalMetric.Kind) -> BodySignalDeltaFormatter {
    switch kind {
    case .wristTemperature:
        let temp = TemperatureUnit.current
        // The delta arrives in Celsius (HealthKit-native).
        // Multiplying by 9/5 scales the magnitude correctly for
        // Fahrenheit — additive offset cancels out for a delta.
        let scale = temp == .fahrenheit ? 9.0 / 5.0 : 1.0
        let symbol = temp.symbol
        return BodySignalDeltaFormatter(flatThreshold: 0.05) {
            String(format: "%.2f%@", $0 * scale, symbol)
        }
    case .hrv:
        return BodySignalDeltaFormatter(flatThreshold: 1.5) { String(format: "%.0f ms", $0) }
    case .restingHR:
        return BodySignalDeltaFormatter(flatThreshold: 0.5) { String(format: "%.0f bpm", $0) }
    }
}

// MARK: - Kind presentation

extension BodySignalMetric.Kind {
    /// Human label used in row titles, chart headers, and
    /// accessibility lines.
    var label: String {
        switch self {
        case .wristTemperature: return "Wrist temperature"
        case .hrv:              return "Heart rate variability"
        case .restingHR:        return "Resting heart rate"
        }
    }

    /// SF Symbol matching Apple Health's own iconography for the
    /// same data type so users recognize the signal immediately.
    /// Filled / hybrid variant — used by the detail sheet headers
    /// where the icon is the dominant visual anchor.
    var sfSymbol: String {
        switch self {
        case .wristTemperature: return "thermometer.medium"
        case .hrv:              return "waveform.path.ecg"
        case .restingHR:        return "heart.fill"
        }
    }

    /// Outline-weight variant used inside the teaser metric rows.
    /// All three return line-only symbols so the left icon column
    /// reads as a uniform set instead of mixing filled + line styles
    /// (which made the heart pop louder than the thermometer / wave).
    var outlineSymbol: String {
        switch self {
        case .wristTemperature: return "thermometer.low"
        case .hrv:              return "waveform.path.ecg"
        case .restingHR:        return "heart"
        }
    }
}
