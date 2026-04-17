import Foundation

// MARK: - Phase Weights + Personal Baseline

/// Phase-aware weight table and personal-baseline-adjusted HBI calculation.
/// Complements the legacy `HBICalculator.calculate` pipeline (fixed weights +
/// phase multipliers) with a "how am I compared to my own typical self in
/// this phase" model. Marketing line: calibrated heuristics, not clinical.
extension HBICalculator {

    // MARK: Phase Weights Table

    /// Per-phase component weights (calibrated heuristics).
    ///
    /// | Phase       | Energy | Mood | Sleep | Calm |
    /// |-------------|--------|------|-------|------|
    /// | Menstrual   |  0.15  | 0.25 | 0.30  | 0.30 |
    /// | Follicular  |  0.30  | 0.25 | 0.20  | 0.25 |
    /// | Ovulatory   |  0.25  | 0.30 | 0.20  | 0.25 |
    /// | Luteal      |  0.20  | 0.25 | 0.25  | 0.30 |
    /// | Late        | luteal weights (fallback)              |
    ///
    /// The optional `clarity` weight is 0 at this layer; callers that have
    /// HealthKit-derived clarity data can extend the weights themselves.
    public static func phaseWeights(for phase: CyclePhase) -> HBIComponentWeights {
        switch phase {
        case .menstrual:
            return HBIComponentWeights(energy: 0.15, mood: 0.25, sleep: 0.30, calm: 0.30)
        case .follicular:
            return HBIComponentWeights(energy: 0.30, mood: 0.25, sleep: 0.20, calm: 0.25)
        case .ovulatory:
            return HBIComponentWeights(energy: 0.25, mood: 0.30, sleep: 0.20, calm: 0.25)
        case .luteal:
            return HBIComponentWeights(energy: 0.20, mood: 0.25, sleep: 0.25, calm: 0.30)
        case .late:
            // "Late" is a tracking state, not a biological phase.
            // Reuse luteal weights as a conservative fallback.
            return HBIComponentWeights(energy: 0.20, mood: 0.25, sleep: 0.25, calm: 0.30)
        }
    }

    // MARK: Personal Baseline

    /// Compute a per-phase personal baseline from historical HBI scores.
    ///
    /// A baseline is only established when the user has seen the phase across
    /// enough independent cycles. Otherwise `averageScore` stays `nil` and
    /// the adjusted-HBI pipeline falls through to the raw score.
    ///
    /// - Parameters:
    ///   - phase: Phase to compute baseline for.
    ///   - historicalScores: All prior `HBIScore` records (any phase —
    ///     filtering happens here).
    ///   - minSamplesRequired: Minimum samples before any baseline is reported.
    /// - Returns: A `PersonalBaseline`. `averageScore` is only non-nil when
    ///   confidence is `.building` or `.established`.
    public static func personalBaseline(
        phase: CyclePhase,
        historicalScores: [HBIScore],
        minSamplesRequired: Int = 6
    ) -> PersonalBaseline {
        let matching = historicalScores.filter { $0.cyclePhase == phase.rawValue }

        // Count distinct cycles by bucketing sample dates.
        // Uses 14-day clustering to approximate distinct menstrual cycles,
        // since each phase occurs at most once per cycle (~28d typical).
        // Two sample dates within 14 days are treated as the same cycle.
        let cyclesRepresented = distinctCycleCount(from: matching.map(\.scoreDate))

        let sampleCount = matching.count

        let confidence: PersonalBaseline.Confidence = {
            if sampleCount < minSamplesRequired || cyclesRepresented < 2 {
                return .insufficient
            }
            if sampleCount >= 12, cyclesRepresented >= 3 {
                return .established
            }
            return .building
        }()

        guard confidence != .insufficient, !matching.isEmpty else {
            return PersonalBaseline(
                phase: phase,
                averageScore: nil,
                sampleCount: sampleCount,
                cyclesRepresented: cyclesRepresented,
                confidence: confidence
            )
        }

        // Average the raw HBI scores — raw, not adjusted, so the baseline is
        // not contaminated by its own adjustment pass.
        let sum = matching.reduce(0) { $0 + Double($1.hbiRaw) }
        let avg = sum / Double(matching.count)

        return PersonalBaseline(
            phase: phase,
            averageScore: avg,
            sampleCount: sampleCount,
            cyclesRepresented: cyclesRepresented,
            confidence: confidence
        )
    }

    /// Approximate distinct-cycle count from a list of sample dates by
    /// bucketing any two samples within 14 days of each other into the same
    /// cycle. Sufficient for cycle-phase baselines where each phase appears
    /// at most once per cycle.
    static func distinctCycleCount(from dates: [Date]) -> Int {
        guard !dates.isEmpty else { return 0 }
        let sorted = dates.sorted()
        var clusters = 1
        var clusterAnchor = sorted[0]
        for date in sorted.dropFirst() {
            let delta = abs(date.timeIntervalSince(clusterAnchor))
            // 14-day threshold in seconds
            if delta > 14 * 24 * 60 * 60 {
                clusters += 1
                clusterAnchor = date
            }
        }
        return clusters
    }

    // MARK: Adjusted HBI with Personal Baseline

    /// Compute the HBI with phase-aware weights and personal-baseline
    /// amplification.
    ///
    /// Math:
    /// ```
    /// weights = phaseWeights(phase) [normalized]
    /// hbiRaw  = sum(weight_i * component_i)
    /// if baseline.averageScore != nil {
    ///     delta = hbiRaw - baseline.averageScore
    ///     hbiAdjusted = clamp(50 + delta * sensitivity, 0, 100)
    /// } else {
    ///     hbiAdjusted = hbiRaw
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - components: 0-100 component scores.
    ///   - phase: Current cycle phase.
    ///   - baseline: Personal baseline. May be `nil` or have `nil`
    ///     `averageScore` — both fall through to `raw`.
    ///   - sensitivity: Multiplier applied to `hbiRaw - baseline`. Default
    ///     `1.2` amplifies deviations slightly so the UI reads more signal.
    /// - Returns: Full `AdjustedHBIResult`.
    public static func calculateAdjustedWithBaseline(
        components: HBIComponents,
        phase: CyclePhase,
        baseline: PersonalBaseline?,
        sensitivity: Double = 1.2
    ) -> AdjustedHBIResult {
        let baseWeights = phaseWeights(for: phase)

        // Incorporate clarity weight only when clarity data is present.
        // Default phase table has clarity=0 — if caller supplies clarity we
        // give it a symmetric share (split from calm, since both are
        // nervous-system signals). For now we keep clarity weight = 0 when
        // clarity missing, and add a flat 0.10 slice redistributed from calm
        // when present. Then normalize so weights sum to 1.0.
        let weights: HBIComponentWeights = {
            guard components.clarity != nil else { return baseWeights.normalized() }
            let claritySlice = 0.10
            return HBIComponentWeights(
                energy: baseWeights.energy,
                mood: baseWeights.mood,
                sleep: baseWeights.sleep,
                calm: max(0, baseWeights.calm - claritySlice),
                clarity: claritySlice
            ).normalized()
        }()

        var hbiRaw =
            weights.energy * components.energy
            + weights.mood * components.mood
            + weights.sleep * components.sleep
            + weights.calm * components.calm
        if let cl = components.clarity {
            hbiRaw += weights.clarity * cl
        }

        let trendVsBaseline = baseline?.averageScore.map { hbiRaw - $0 }

        let adjusted: Double = {
            guard let avg = baseline?.averageScore else { return hbiRaw }
            let delta = hbiRaw - avg
            return min(100, max(0, 50 + delta * sensitivity))
        }()

        return AdjustedHBIResult(
            raw: hbiRaw,
            adjusted: adjusted,
            trendVsBaseline: trendVsBaseline,
            baseline: baseline,
            weights: weights,
            hasHealthKitData: false,
            completenessScore: 0
        )
    }

    /// Convenience overload that injects HealthKit/completeness metadata
    /// around the pure compute. Kept separate so the core math stays testable
    /// without needing to thread booleans through every test.
    public static func calculateAdjustedWithBaseline(
        components: HBIComponents,
        phase: CyclePhase,
        baseline: PersonalBaseline?,
        sensitivity: Double = 1.2,
        hasHealthKitData: Bool,
        completenessScore: Double
    ) -> AdjustedHBIResult {
        let result = calculateAdjustedWithBaseline(
            components: components,
            phase: phase,
            baseline: baseline,
            sensitivity: sensitivity
        )
        return AdjustedHBIResult(
            raw: result.raw,
            adjusted: result.adjusted,
            trendVsBaseline: result.trendVsBaseline,
            baseline: result.baseline,
            weights: result.weights,
            hasHealthKitData: hasHealthKitData,
            completenessScore: completenessScore
        )
    }
}
