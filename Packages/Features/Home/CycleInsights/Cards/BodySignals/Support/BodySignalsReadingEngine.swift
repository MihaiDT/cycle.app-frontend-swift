import Foundation

// MARK: - Body Signals Reading Engine
//
// Pure function generator for the Reading section copy that sits
// beneath each metric chart on the focused BodySignals screens
// (Wrist temperature / HRV / Resting heart rate). Picks one
// variant per metric from `BodySignalsReadingTemplates`.
//
// Variant strategy:
//   The seed combines the metric kind + the user's sample count
//   so that:
//     • Same metric, same data state → same variant within a
//       session (no copy thrashing while the user reads).
//     • Across cycles, the sample count shifts and the variant
//       rotates naturally without needing a clock.
//   Falls back to a kind-only seed when no metric is available
//   yet (empty / "Soon" state) so the explanation copy still
//   renders deterministically.
//
// Hash is djb2 – stable across launches, unlike Swift's
// randomised `hashValue`. Selector mirrors the strategy used by
// `BodyPatternsReadingEngine`.

enum BodySignalsReadingEngine {

    /// Picks the right template list for the metric and renders
    /// one variant. Branches on `metric.hasData` so the empty
    /// state ("No Data" + "Soon") gets forward-looking copy
    /// ("once samples land you'll see…") instead of the
    /// reflective copy ("each dot is a single night…") that
    /// references chart visuals that aren't there yet.
    static func reading(for kind: BodySignalMetric.Kind, metric: BodySignalMetric?) -> String {
        let templates = templates(for: kind, hasData: metric?.hasData == true)
        guard !templates.isEmpty else { return "" }
        let seed = stableHash(seedKey(for: kind, metric: metric))
        return templates[abs(seed) % templates.count]
    }

    // MARK: - Internals

    private static func templates(for kind: BodySignalMetric.Kind, hasData: Bool) -> [String] {
        switch (kind, hasData) {
        case (.wristTemperature, true):  return BodySignalsReadingTemplates.wristTemperature
        case (.wristTemperature, false): return BodySignalsReadingTemplates.wristTemperatureSoon
        case (.hrv, true):               return BodySignalsReadingTemplates.hrv
        case (.hrv, false):              return BodySignalsReadingTemplates.hrvSoon
        case (.restingHR, true):         return BodySignalsReadingTemplates.restingHR
        case (.restingHR, false):        return BodySignalsReadingTemplates.restingHRSoon
        }
    }

    /// Stable seed input. The sample count gives cross-cycle
    /// variance without leaning on a clock; the kind raw value
    /// keeps the three metrics separate even when the same user
    /// has identical sample counts across them.
    private static func seedKey(for kind: BodySignalMetric.Kind, metric: BodySignalMetric?) -> String {
        let count = metric?.samples.count ?? 0
        return "\(kind.rawValue)_n\(count)"
    }

    private static func stableHash(_ s: String) -> Int {
        var hash: UInt32 = 5381
        for byte in s.utf8 {
            hash = hash &* 33 &+ UInt32(byte)
        }
        return Int(hash & 0x7FFFFFFF)
    }
}
