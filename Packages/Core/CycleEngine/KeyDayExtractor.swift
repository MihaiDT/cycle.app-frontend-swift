import Foundation

// MARK: - Key Day
//
// A single notable day within a cycle — used by Chapter 5 of the recap.
// Selection is deterministic (not AI): the engine scores each tracked
// day against a set of signals and surfaces the few that "stand out",
// so the narrative in the recap rests on real, reproducible data.

public struct KeyDay: Equatable, Sendable, Identifiable {
    public enum Reason: String, Equatable, Sendable, Codable {
        case hbiPeak          // highest HBI of the cycle
        case hbiValley        // lowest HBI of the cycle
        case moodLift         // mood jumped meaningfully vs prior day
        case moodDip          // mood dropped meaningfully
        case energyBoost      // energy surge
        case energyCrash      // energy drop
        case stressPeak       // stress hit a high
        case poorSleep        // sleep rated 1
        case greatSleep       // sleep rated 5
        case momentCompleted  // the user did a daily moment
        case phaseStart       // first day of a cycle phase (follicular/ovulatory/luteal)
    }

    public let id: UUID
    public let day: Int
    public let phase: CyclePhase
    public let hbi: Int?
    public let mood: Int?
    public let energy: Int?
    public let reasons: [Reason]
    /// Short narrative explaining why this day stood out. Populated by
    /// the template fallback immediately and optionally rewritten by AI
    /// later when the full recap generates.
    public let narrative: String
    /// Category of a moment completed on this day (if any) — lets the
    /// narrative reference the specific practice without re-fetching.
    public let momentCategory: String?

    public init(
        id: UUID = UUID(),
        day: Int,
        phase: CyclePhase,
        hbi: Int?,
        mood: Int?,
        energy: Int?,
        reasons: [Reason],
        narrative: String,
        momentCategory: String? = nil
    ) {
        self.id = id
        self.day = day
        self.phase = phase
        self.hbi = hbi
        self.mood = mood
        self.energy = energy
        self.reasons = reasons
        self.narrative = narrative
        self.momentCategory = momentCategory
    }
}

// MARK: - Day Signal

/// Per-day data bundle passed into the extractor. The caller assembles
/// this from their persistence layer so the engine stays pure.
public struct KeyDaySignal: Equatable, Sendable {
    public let day: Int
    public let hbi: Int?
    public let mood: Int?
    public let energy: Int?
    public let stress: Int?
    public let sleep: Int?
    public let momentCategory: String?

    public init(
        day: Int,
        hbi: Int? = nil,
        mood: Int? = nil,
        energy: Int? = nil,
        stress: Int? = nil,
        sleep: Int? = nil,
        momentCategory: String? = nil
    ) {
        self.day = day
        self.hbi = hbi
        self.mood = mood
        self.energy = energy
        self.stress = stress
        self.sleep = sleep
        self.momentCategory = momentCategory
    }
}

// MARK: - Extractor

public enum KeyDayExtractor {

    /// Pick the days that carried the most meaning this cycle. Output is
    /// sorted by day ascending so the recap reads chronologically.
    public static func extract(
        signals: [KeyDaySignal],
        cycleLength: Int,
        bleedingDays: Int,
        maxDays: Int = 4
    ) -> [KeyDay] {
        guard !signals.isEmpty, cycleLength > 0 else { return [] }

        let sorted = signals.sorted { $0.day < $1.day }
        let indexByDay: [Int: Int] = Dictionary(uniqueKeysWithValues: sorted.enumerated().map { ($1.day, $0) })

        let hbiValues = sorted.compactMap(\.hbi)
        let maxHBI = hbiValues.max()
        let minHBI = hbiValues.min()

        // Score every candidate day
        var scored: [(signal: KeyDaySignal, score: Int, reasons: [KeyDay.Reason])] = []
        for signal in sorted {
            var score = 0
            var reasons: [KeyDay.Reason] = []

            if let hbi = signal.hbi {
                if let maxHBI, hbi == maxHBI, hbiValues.count > 1 {
                    score += 50
                    reasons.append(.hbiPeak)
                }
                if let minHBI, hbi == minHBI, hbiValues.count > 1 {
                    score += 50
                    reasons.append(.hbiValley)
                }
            }

            // Prior-day comparison for swings (needs ordered access)
            let dayIndex = indexByDay[signal.day] ?? 0
            if dayIndex > 0 {
                let prior = sorted[dayIndex - 1]
                if let m = signal.mood, let pm = prior.mood {
                    if m - pm >= 2 { score += 25; reasons.append(.moodLift) }
                    if pm - m >= 2 { score += 25; reasons.append(.moodDip) }
                }
                if let e = signal.energy, let pe = prior.energy {
                    if e - pe >= 2 { score += 25; reasons.append(.energyBoost) }
                    if pe - e >= 2 { score += 25; reasons.append(.energyCrash) }
                }
            }

            if let stress = signal.stress, stress >= 4 {
                score += 20
                reasons.append(.stressPeak)
            }
            if let sleep = signal.sleep {
                if sleep == 1 { score += 15; reasons.append(.poorSleep) }
                if sleep == 5 { score += 15; reasons.append(.greatSleep) }
            }
            if signal.momentCategory != nil {
                score += 30
                reasons.append(.momentCompleted)
            }

            if isPhaseStart(day: signal.day, bleedingDays: bleedingDays, cycleLength: cycleLength) {
                score += 15
                reasons.append(.phaseStart)
            }

            if score > 0 {
                scored.append((signal, score, reasons))
            }
        }

        // Sort candidates by score descending, break ties by HBI magnitude
        scored.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            return (a.signal.hbi ?? 0) > (b.signal.hbi ?? 0)
        }

        // Greedy pick with diversity: avoid two candidates back-to-back
        var picked: [(signal: KeyDaySignal, reasons: [KeyDay.Reason])] = []
        for candidate in scored {
            guard picked.count < maxDays else { break }
            let day = candidate.signal.day
            let tooClose = picked.contains { abs($0.signal.day - day) < 2 }
            if tooClose { continue }
            picked.append((candidate.signal, candidate.reasons))
        }

        // Sort final picks chronologically
        picked.sort { $0.signal.day < $1.signal.day }

        return picked.map { pick in
            let phaseResult = CycleMath.cyclePhase(
                cycleDay: pick.signal.day,
                cycleLength: cycleLength,
                bleedingDays: bleedingDays
            )
            // Map the engine's internal phase enum to the UI-facing one.
            // Same raw values, safe to bridge via rawValue.
            let phase = CyclePhase(rawValue: phaseResult.rawValue) ?? .menstrual
            let narrative = templateNarrative(
                reasons: pick.reasons,
                signal: pick.signal,
                phase: phase
            )
            return KeyDay(
                day: pick.signal.day,
                phase: phase,
                hbi: pick.signal.hbi,
                mood: pick.signal.mood,
                energy: pick.signal.energy,
                reasons: pick.reasons,
                narrative: narrative,
                momentCategory: pick.signal.momentCategory
            )
        }
    }

    // MARK: - Phase start detection

    private static func isPhaseStart(day: Int, bleedingDays: Int, cycleLength: Int) -> Bool {
        // Only treat the first day of follicular / ovulatory / luteal as a
        // "phase start" — menstrual day 1 is the cycle start, not an
        // inflection worth highlighting separately.
        let follicularStart = bleedingDays + 1
        let ovulatoryStart = max(1, cycleLength - 16)
        let lutealStart = max(1, cycleLength - 13)
        return day == follicularStart || day == ovulatoryStart || day == lutealStart
    }

    // MARK: - Template narrative

    /// Deterministic fallback narrative. AI can replace this with a
    /// warmer rewrite later; the template keeps the app self-sufficient
    /// when the network fails or the user is offline.
    private static func templateNarrative(
        reasons: [KeyDay.Reason],
        signal: KeyDaySignal,
        phase: CyclePhase
    ) -> String {
        let primary = reasons.first

        switch primary {
        case .hbiPeak:
            return "Your peak day. Energy, mood, and pace all lined up."
        case .hbiValley:
            return "Your quietest day. Your body chose rest and you listened."
        case .moodLift:
            return "Something lifted — your mood climbed without needing to be told."
        case .moodDip:
            return "A softer day emotionally. Not every cycle day has to feel bright."
        case .energyBoost:
            return "Your energy surged. The \(phase.displayName.lowercased()) phase does this."
        case .energyCrash:
            return "Your energy dipped. Your body was asking for a pause."
        case .stressPeak:
            return "Stress ran high this day. Worth remembering what triggered it."
        case .greatSleep:
            return "A night of deep rest. Your body repaid you the next day."
        case .poorSleep:
            return "A rough night of sleep. Everything else feels heavier after one."
        case .momentCompleted:
            if let cat = signal.momentCategory {
                return "You chose a \(humanCategory(cat)) moment today — and it showed."
            }
            return "You took a moment for yourself today."
        case .phaseStart:
            return "The \(phase.displayName.lowercased()) phase begins. A new chapter in the cycle."
        case .none:
            return "A day worth remembering."
        }
    }

    private static func humanCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "self_care":   return "self-care"
        case "mindfulness": return "mindful"
        case "movement":    return "movement"
        case "creative":    return "creative"
        case "nutrition":   return "nourishing"
        case "social":      return "connection"
        default:            return category.lowercased()
        }
    }
}
