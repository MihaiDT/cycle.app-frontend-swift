import Foundation

// MARK: - Pattern Detector
//
// Pure local algorithm that surfaces recurring body-pattern signals
// from the user's symptom + cycle history. Phase 2 deliverable per
// `Packages/Features/Home/BodyPatterns/CLAUDE.md`.
//
// Threshold (per spec):
//   - ≥3 cycles in same phase logged the same symptom → confirmed
//     (emerging = false).
//   - exactly 2 cycles → emerging (emerging = true).
//   - <2 cycles → dropped (no signal).
//
// Lookback: caller-provided (default callers pass 12 months). The
// detector itself takes already-filtered snapshots — keeping the
// SwiftData query out of CycleEngine so this stays a pure function.
//
// The detector returns a value-type `RawPatternSignal` rather than
// the `DetectedPattern` UI model, so CycleEngine doesn't reach into
// the Features layer. The `MenstrualLocalClient.detectPatterns`
// seam maps raw signals → `DetectedPattern` with display names +
// editorial copy.

public enum PatternDetector {

    // MARK: Filters

    /// SymptomType raw values that should NOT be surfaced as
    /// patterns — neutral / positive entries the user logs to
    /// affirm a good day, not biological signals to track.
    public static let neutralSymptoms: Set<String> = [
        "all_good",
        "calm",
        "happy",
        "energetic",
        "focused"
    ]

    // MARK: Inputs

    /// Snapshot of one cycle in the lookback window — exactly what
    /// the detector needs, no SwiftData coupling.
    public struct CycleSnapshot: Sendable, Hashable {
        public let id: String
        public let cycleLength: Int
        public let bleedingDays: Int

        public init(id: String, cycleLength: Int, bleedingDays: Int) {
            self.id = id
            self.cycleLength = cycleLength
            self.bleedingDays = bleedingDays
        }
    }

    /// Snapshot of one symptom log in the lookback window.
    public struct SymptomSnapshot: Sendable, Hashable {
        /// Cycle this log belongs to. Maps to `CycleSnapshot.id`.
        public let cycleID: String

        /// Raw `SymptomType.rawValue` so the detector stays
        /// agnostic of the SymptomType enum's UI affordances.
        public let symptomTypeRaw: String

        /// Day-of-cycle the symptom was logged on (1-based).
        public let cycleDay: Int

        public init(cycleID: String, symptomTypeRaw: String, cycleDay: Int) {
            self.cycleID = cycleID
            self.symptomTypeRaw = symptomTypeRaw
            self.cycleDay = cycleDay
        }
    }

    // MARK: Output

    /// Raw pattern signal — pure algorithm output, no display copy.
    public struct RawPatternSignal: Sendable, Hashable {
        public let symptomTypeRaw: String
        public let phase: CyclePhaseResult
        public let occurrences: Int
        public let totalCycles: Int
        public let dayRange: ClosedRange<Int>
        public let isEmerging: Bool
    }

    // MARK: Detection

    /// Detect recurring patterns. `symptomFilter` lets the caller
    /// drop neutral / positive entries (e.g. "all_good") that
    /// shouldn't surface as a "pattern" in the UI; default keeps
    /// every symptom.
    public static func detect(
        cycles: [CycleSnapshot],
        symptoms: [SymptomSnapshot],
        symptomFilter: (String) -> Bool = { _ in true }
    ) -> [RawPatternSignal] {
        guard !cycles.isEmpty else { return [] }

        // Index cycles by ID so we can resolve each symptom's phase.
        let cyclesByID = Dictionary(uniqueKeysWithValues: cycles.map { ($0.id, $0) })
        let totalCycles = cycles.count

        // Group by (symptomTypeRaw, phase) → for each group, track
        // the set of distinct cycle IDs where this combo appeared
        // and the min / max cycleDay observed.
        struct GroupAggregate {
            var cycleIDs: Set<String> = []
            var dayMin: Int = .max
            var dayMax: Int = .min
        }

        struct GroupKey: Hashable {
            let symptomTypeRaw: String
            let phase: CyclePhaseResult
        }

        var groups: [GroupKey: GroupAggregate] = [:]

        for symptom in symptoms {
            guard symptomFilter(symptom.symptomTypeRaw) else { continue }
            guard let cycle = cyclesByID[symptom.cycleID] else { continue }

            let phase = CycleMath.cyclePhase(
                cycleDay: symptom.cycleDay,
                cycleLength: cycle.cycleLength,
                bleedingDays: cycle.bleedingDays
            )

            // Skip "late" — it's a tracking state, not a biological
            // phase. Patterns logged outside the cycle window aren't
            // hormonal signals.
            guard phase != .late else { continue }

            let key = GroupKey(symptomTypeRaw: symptom.symptomTypeRaw, phase: phase)
            var agg = groups[key, default: GroupAggregate()]
            agg.cycleIDs.insert(symptom.cycleID)
            agg.dayMin = min(agg.dayMin, symptom.cycleDay)
            agg.dayMax = max(agg.dayMax, symptom.cycleDay)
            groups[key] = agg
        }

        // Filter to combos with ≥2 distinct cycles + emit signal.
        var signals: [RawPatternSignal] = []
        for (key, agg) in groups {
            let occurrences = agg.cycleIDs.count
            guard occurrences >= 2 else { continue }

            let isEmerging = occurrences == 2
            let dayRange = agg.dayMin...agg.dayMax

            signals.append(
                RawPatternSignal(
                    symptomTypeRaw: key.symptomTypeRaw,
                    phase: key.phase,
                    occurrences: occurrences,
                    totalCycles: totalCycles,
                    dayRange: dayRange,
                    isEmerging: isEmerging
                )
            )
        }

        // Stable order: confirmed first (occurrences desc), then
        // emerging (occurrences desc), tie-break by symptomTypeRaw
        // for determinism.
        signals.sort { lhs, rhs in
            if lhs.isEmerging != rhs.isEmerging { return !lhs.isEmerging }
            if lhs.occurrences != rhs.occurrences { return lhs.occurrences > rhs.occurrences }
            return lhs.symptomTypeRaw < rhs.symptomTypeRaw
        }

        return signals
    }
}
