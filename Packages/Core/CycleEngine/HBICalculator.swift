import Foundation

// MARK: - HBI Calculator

/// Hormonal Balance Index calculator.
/// Ported 1:1 from dth-backend/internal/service/hbi_calculator.go
public enum HBICalculator {

    // MARK: Weights

    /// Component weights for the composite HBI score.
    public static let weights = ComponentWeights(
        energy: 0.30,
        sleep: 0.25,
        stress: 0.25,
        mood: 0.20
    )

    // MARK: Phase Multipliers

    /// Phase-specific multipliers adjust component scores to reflect hormonal influence.
    public static func phaseMultipliers(for phase: CyclePhaseResult) -> PhaseMultipliers {
        switch phase {
        case .menstrual:
            PhaseMultipliers(energy: 0.80, anxiety: 1.10, sleep: 0.85, mood: 0.90)
        case .follicular:
            PhaseMultipliers(energy: 1.10, anxiety: 0.90, sleep: 1.00, mood: 1.10)
        case .ovulatory:
            PhaseMultipliers(energy: 1.20, anxiety: 0.85, sleep: 1.00, mood: 1.15)
        case .luteal:
            PhaseMultipliers(energy: 0.85, anxiety: 1.20, sleep: 0.90, mood: 0.85)
        case .late:
            PhaseMultipliers(energy: 0.85, anxiety: 1.15, sleep: 0.90, mood: 0.85)
        }
    }

    // MARK: Score Conversion

    /// Convert Likert 1-5 self-report to 0-100 scale.
    public static func likertToScore(_ value: Int) -> Double {
        Double(max(1, min(5, value))) * 20.0
    }

    /// Invert a Likert 1-5 score (for stress: high stress = low score).
    public static func likertToScoreInverted(_ value: Int) -> Double {
        Double(6 - max(1, min(5, value))) * 20.0
    }

    // MARK: HealthKit Component Scores

    /// Energy score from HealthKit: 60% HRV + 40% Steps.
    public static func energyScoreFromHealthKit(
        hrvAvg: Double?,
        steps: Double?
    ) -> Double? {
        guard hrvAvg != nil || steps != nil else { return nil }

        let hrvComponent: Double = {
            guard let hrv = hrvAvg else { return 50.0 }
            return normalize(hrv, min: 20, max: 100) * 100
        }()

        let stepsComponent: Double = {
            guard let s = steps else { return 50.0 }
            return normalize(s, min: 0, max: 15000) * 100
        }()

        return hrvComponent * 0.6 + stepsComponent * 0.4
    }

    /// Anxiety score from HealthKit: 70% HRV (inverted) + 30% RHR (inverted).
    /// Lower HRV = higher stress, higher RHR = higher stress.
    public static func anxietyScoreFromHealthKit(
        hrvAvg: Double?,
        rhrAvg: Double?
    ) -> Double? {
        guard hrvAvg != nil || rhrAvg != nil else { return nil }

        let hrvComponent: Double = {
            guard let hrv = hrvAvg else { return 50.0 }
            return (1.0 - normalize(hrv, min: 20, max: 100)) * 100
        }()

        let rhrComponent: Double = {
            guard let rhr = rhrAvg else { return 50.0 }
            return (1.0 - normalize(rhr, min: 40, max: 90)) * 100
        }()

        return hrvComponent * 0.7 + rhrComponent * 0.3
    }

    /// Sleep score from HealthKit hours. Optimal: 7-9h, peak at 8h.
    public static func sleepScoreFromHealthKit(hours: Double?) -> Double? {
        guard let h = hours else { return nil }
        if h >= 7, h <= 9 {
            return 90.0 + 10.0 * (1.0 - abs(h - 8.0))
        } else if h < 7 {
            return (h / 7.0) * 90.0
        } else {
            return max(50, 90.0 - (h - 9.0) * 5.0)
        }
    }

    /// Mood score from HealthKit: HRV normalized + mindfulness bonus.
    public static func moodScoreFromHealthKit(
        hrvAvg: Double?,
        mindfulMinutes: Double?
    ) -> Double? {
        guard let hrv = hrvAvg else { return nil }
        let base = normalize(hrv, min: 20, max: 100) * 100
        let bonus = min(10.0, (mindfulMinutes ?? 0) / 6.0)
        return min(100, base + bonus)
    }

    // MARK: Calculate HBI

    /// Main HBI calculation from a self-report, optional HealthKit data, and cycle phase.
    ///
    /// Returns an `HBIResult` with raw score, phase-adjusted score, and component breakdown.
    public static func calculate(
        selfReport: SelfReportInput,
        healthKit: HealthKitInput? = nil,
        cyclePhase: CyclePhaseResult? = nil,
        cycleDay: Int? = nil
    ) -> HBIResult {

        // Component scores: prefer HealthKit, fallback to self-report

        let energyScore: Double = healthKit.flatMap {
            energyScoreFromHealthKit(hrvAvg: $0.hrvAvg, steps: $0.steps)
        } ?? likertToScore(selfReport.energyLevel)

        let anxietyScore: Double = healthKit.flatMap {
            anxietyScoreFromHealthKit(hrvAvg: $0.hrvAvg, rhrAvg: $0.rhrAvg)
        } ?? likertToScoreInverted(selfReport.stressLevel)

        let sleepScore: Double = healthKit.flatMap {
            sleepScoreFromHealthKit(hours: $0.sleepHours)
        } ?? likertToScore(selfReport.sleepQuality)

        let moodScore: Double = healthKit.flatMap {
            moodScoreFromHealthKit(hrvAvg: $0.hrvAvg, mindfulMinutes: $0.mindfulMinutes)
        } ?? likertToScore(selfReport.moodLevel)

        // Raw HBI
        let hbiRaw = energyScore * weights.energy
            + sleepScore * weights.sleep
            + anxietyScore * weights.stress
            + moodScore * weights.mood

        // Phase-adjusted HBI
        var hbiAdjusted = hbiRaw
        var multiplierAvg = 1.0

        if let phase = cyclePhase {
            let m = phaseMultipliers(for: phase)
            hbiAdjusted = energyScore * m.energy * weights.energy
                + sleepScore * m.sleep * weights.sleep
                + anxietyScore * m.anxiety * weights.stress
                + moodScore * m.mood * weights.mood
            multiplierAvg = (m.energy + m.anxiety + m.sleep + m.mood) / 4.0
        }

        // Completeness
        let completeness: Double = {
            var score = 0.0
            if true { score += 50 } // self-report always present
            if healthKit != nil { score += 50 }
            return score
        }()

        return HBIResult(
            energyScore: energyScore,
            anxietyScore: anxietyScore,
            sleepScore: sleepScore,
            moodScore: moodScore,
            clarityScore: nil,
            hbiRaw: hbiRaw,
            hbiAdjusted: hbiAdjusted,
            cyclePhase: cyclePhase,
            cycleDay: cycleDay,
            phaseMultiplier: multiplierAvg,
            hasHealthKitData: healthKit != nil,
            hasSelfReport: true,
            completenessScore: completeness
        )
    }

    /// Calculate 30-day baseline from historical scores.
    /// Requires at least 7 days of data.
    public static func calculateBaseline(scores: [Double]) -> Double? {
        guard scores.count >= 7 else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    /// Trend vs baseline: % deviation from baseline.
    public static func trendVsBaseline(current: Double, baseline: Double) -> Double {
        guard baseline > 0 else { return 0 }
        return ((current - baseline) / baseline) * 100
    }

    /// Trend direction string from deviation.
    public static func trendDirection(deviation: Double) -> String {
        if deviation > 2 { return "up" }
        if deviation < -2 { return "down" }
        return "stable"
    }

    // MARK: Private Helpers

    /// Normalize a value to 0-1 range within [min, max].
    private static func normalize(_ value: Double, min lo: Double, max hi: Double) -> Double {
        Swift.max(0, Swift.min(1, (value - lo) / (hi - lo)))
    }
}

// MARK: - Input / Output Types

public struct SelfReportInput: Sendable, Equatable {
    public let energyLevel: Int      // 1-5
    public let stressLevel: Int      // 1-5
    public let sleepQuality: Int     // 1-5
    public let moodLevel: Int        // 1-5

    public init(energyLevel: Int, stressLevel: Int, sleepQuality: Int, moodLevel: Int) {
        self.energyLevel = energyLevel
        self.stressLevel = stressLevel
        self.sleepQuality = sleepQuality
        self.moodLevel = moodLevel
    }
}

public struct HealthKitInput: Sendable, Equatable {
    public let hrvAvg: Double?       // ms (20-100 typical)
    public let rhrAvg: Double?       // bpm (40-90 typical)
    public let steps: Double?        // count (0-15000)
    public let sleepHours: Double?   // hours (0-12)
    public let mindfulMinutes: Double?

    public init(
        hrvAvg: Double? = nil,
        rhrAvg: Double? = nil,
        steps: Double? = nil,
        sleepHours: Double? = nil,
        mindfulMinutes: Double? = nil
    ) {
        self.hrvAvg = hrvAvg
        self.rhrAvg = rhrAvg
        self.steps = steps
        self.sleepHours = sleepHours
        self.mindfulMinutes = mindfulMinutes
    }
}

public struct HBIResult: Sendable, Equatable {
    public let energyScore: Double
    public let anxietyScore: Double
    public let sleepScore: Double
    public let moodScore: Double
    public let clarityScore: Double?
    public let hbiRaw: Double
    public let hbiAdjusted: Double
    public let cyclePhase: CyclePhaseResult?
    public let cycleDay: Int?
    public let phaseMultiplier: Double
    public let hasHealthKitData: Bool
    public let hasSelfReport: Bool
    public let completenessScore: Double
}

public struct ComponentWeights: Sendable {
    public let energy: Double
    public let sleep: Double
    public let stress: Double
    public let mood: Double
}

public struct PhaseMultipliers: Sendable {
    public let energy: Double
    public let anxiety: Double
    public let sleep: Double
    public let mood: Double
}
