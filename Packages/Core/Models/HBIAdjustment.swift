import Foundation

// MARK: - Phase-Aware Component Weights

/// Per-component weights for the HBI composite score.
/// Unlike the legacy fixed `ComponentWeights` (energy/sleep/stress/mood),
/// this structure is phase-aware and uses the "calm" framing (higher = better)
/// instead of "anxiety". Optional `clarity` weight kicks in only when HealthKit
/// supplies the clarity component.
///
/// Not a clinical model — calibrated heuristics per phase.
public struct HBIComponentWeights: Sendable, Equatable {
    public let energy: Double
    public let mood: Double
    public let sleep: Double
    public let calm: Double
    public let clarity: Double

    public init(
        energy: Double,
        mood: Double,
        sleep: Double,
        calm: Double,
        clarity: Double = 0
    ) {
        self.energy = energy
        self.mood = mood
        self.sleep = sleep
        self.calm = calm
        self.clarity = clarity
    }

    /// Sum of all weights.
    public var total: Double {
        energy + mood + sleep + calm + clarity
    }

    /// Rescale all weights so they sum to 1.0. If the current sum is 0,
    /// returns self unchanged.
    public func normalized() -> HBIComponentWeights {
        let t = total
        guard t > 0 else { return self }
        return HBIComponentWeights(
            energy: energy / t,
            mood: mood / t,
            sleep: sleep / t,
            calm: calm / t,
            clarity: clarity / t
        )
    }
}

// MARK: - Personal Baseline

/// A user's personal average HBI for a given cycle phase.
/// Used to amplify deviations from the user's own typical state rather than
/// comparing to a fixed 50 midpoint.
public struct PersonalBaseline: Sendable, Equatable {
    /// Which phase this baseline represents.
    public let phase: CyclePhase

    /// Average raw HBI across matching same-phase historical scores.
    /// `nil` when confidence is `.insufficient`.
    public let averageScore: Double?

    /// Number of historical samples that contributed.
    public let sampleCount: Int

    /// Number of distinct menstrual cycles those samples spanned.
    public let cyclesRepresented: Int

    /// Derived confidence — see `Confidence`.
    public let confidence: Confidence

    public init(
        phase: CyclePhase,
        averageScore: Double?,
        sampleCount: Int,
        cyclesRepresented: Int,
        confidence: Confidence
    ) {
        self.phase = phase
        self.averageScore = averageScore
        self.sampleCount = sampleCount
        self.cyclesRepresented = cyclesRepresented
        self.confidence = confidence
    }

    /// Baseline confidence tier — drives whether the HBI adjustment falls
    /// through to the raw score or amplifies the delta vs baseline.
    public enum Confidence: String, Sendable, Equatable {
        /// < 6 samples or < 2 cycles — baseline cannot be trusted.
        case insufficient
        /// 6-11 samples across exactly 2 cycles — early signal.
        case building
        /// 12+ samples across 3+ cycles — trusted baseline.
        case established
    }

    /// An empty baseline to return when no data is available for the phase.
    public static func empty(phase: CyclePhase) -> PersonalBaseline {
        PersonalBaseline(
            phase: phase,
            averageScore: nil,
            sampleCount: 0,
            cyclesRepresented: 0,
            confidence: .insufficient
        )
    }
}

// MARK: - Adjusted HBI Result

/// Full result of the personal-baseline-aware HBI calculation.
/// `raw` is the pure weighted average. `adjusted` applies the baseline
/// amplification (or falls back to `raw` when baseline is insufficient).
public struct AdjustedHBIResult: Sendable, Equatable {
    public let raw: Double
    public let adjusted: Double

    /// Signed delta between `raw` and `baseline.averageScore`.
    /// `nil` when baseline has no average.
    public let trendVsBaseline: Double?

    /// Baseline used during adjustment. `nil` when caller passed no baseline.
    public let baseline: PersonalBaseline?

    /// Phase-specific weights actually applied (normalized).
    public let weights: HBIComponentWeights

    /// Whether any HealthKit data influenced the components.
    public let hasHealthKitData: Bool

    /// 0-100 completeness (fraction of ideal signal available).
    public let completenessScore: Double

    public init(
        raw: Double,
        adjusted: Double,
        trendVsBaseline: Double?,
        baseline: PersonalBaseline?,
        weights: HBIComponentWeights,
        hasHealthKitData: Bool,
        completenessScore: Double
    ) {
        self.raw = raw
        self.adjusted = adjusted
        self.trendVsBaseline = trendVsBaseline
        self.baseline = baseline
        self.weights = weights
        self.hasHealthKitData = hasHealthKitData
        self.completenessScore = completenessScore
    }
}

// MARK: - HBI Components Input

/// Per-component scores on the 0-100 scale, already resolved from either
/// HealthKit or Likert self-report. Passed into
/// `HBICalculator.calculateAdjustedWithBaseline`.
public struct HBIComponents: Sendable, Equatable {
    public let energy: Double
    public let mood: Double
    public let sleep: Double
    public let calm: Double
    public let clarity: Double?

    public init(
        energy: Double,
        mood: Double,
        sleep: Double,
        calm: Double,
        clarity: Double? = nil
    ) {
        self.energy = energy
        self.mood = mood
        self.sleep = sleep
        self.calm = calm
        self.clarity = clarity
    }
}
