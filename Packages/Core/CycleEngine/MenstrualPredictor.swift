import Foundation

// MARK: - Menstrual Predictor

/// Adaptive menstrual cycle prediction engine with 4 algorithm tiers.
/// Ported 1:1 from dth-backend/internal/menstrual/calculator.go
///
/// Algorithm selection:
/// - V1 Basic  (0 cycles):   onboarding data only, ~70% accuracy
/// - V2 WMA    (1-2 cycles): exponential weighted moving average, ~80%
/// - V3 Ogino  (3-5 cycles): trend + age + Ogino-Knaus fertile window, ~88%
/// - V4 ML     (6+ cycles):  V3 + confirmation learning + seasonal patterns, ~93%
public enum MenstrualPredictor {

    // MARK: - Public API

    /// Predict the next period based on cycle history and profile.
    ///
    /// - Parameters:
    ///   - cycles: Historical cycles sorted newest-first. Each needs `startDate` and
    ///     optionally `actualCycleLength`, `isConfirmed`, `actualDeviationDays`.
    ///   - profile: User's menstrual profile (avg length, regularity, etc.)
    ///   - age: User's age (for V3+ age-adjusted predictions).
    ///   - hasSymptomData: Whether any symptoms have been logged.
    /// - Returns: A `PredictionResult` with dates, confidence, fertile window, and metadata.
    public static func predict(
        cycles: [CycleInput],
        profile: ProfileInput,
        age: Int? = nil,
        hasSymptomData: Bool = false
    ) -> PredictionResult {
        let version = determineVersion(cycleCount: cycles.count)

        switch version {
        case .v1Basic:
            return predictV1(profile: profile, lastPeriod: cycles.first?.startDate)
        case .v2Statistical:
            return predictV2(cycles: cycles, profile: profile, hasSymptomData: hasSymptomData)
        case .v3Historical:
            return predictV3(
                cycles: cycles, profile: profile,
                age: age, hasSymptomData: hasSymptomData
            )
        case .v4ML:
            return predictV4(
                cycles: cycles, profile: profile,
                age: age, hasSymptomData: hasSymptomData
            )
        }
    }

    /// Select algorithm version based on available data.
    public static func determineVersion(cycleCount: Int) -> AlgorithmVersion {
        switch cycleCount {
        case 0: return .v1Basic
        case 1...2: return .v2Statistical
        case 3...5: return .v3Historical
        default: return .v4ML
        }
    }

    // MARK: - V1: Basic

    /// Uses only onboarding data — profile averages and optional last period date.
    private static func predictV1(
        profile: ProfileInput,
        lastPeriod: Date?
    ) -> PredictionResult {
        let today = CycleMath.startOfDay(Date())
        let cycleLength = profile.avgCycleLength
        let bleedingDays = profile.avgBleedingDays

        var predictedStart: Date
        if let lp = lastPeriod {
            predictedStart = CycleMath.addDays(lp, cycleLength)
            // Project forward if in the past (allow 60 days back for late detection)
            let cutoff = CycleMath.addDays(today, -60)
            while predictedStart < cutoff {
                predictedStart = CycleMath.addDays(predictedStart, cycleLength)
            }
        } else {
            predictedStart = CycleMath.addDays(today, cycleLength / 2)
        }

        let predictedEnd = CycleMath.addDays(predictedStart, bleedingDays - 1)

        let confidence = CycleMath.calculateConfidence(
            cycleCount: 0, regularity: profile.cycleRegularity,
            hasSymptomData: false, stdDev: 0
        )
        let rangeDays = CycleMath.predictionRangeDays(confidence: confidence, stdDev: 0)

        let fertileWindow = CycleMath.simpleFertileWindow(
            cycleStart: predictedStart, cycleLength: cycleLength
        )

        return PredictionResult(
            predictedStart: predictedStart,
            predictedEnd: predictedEnd,
            fertileWindow: fertileWindow,
            confidence: confidence,
            algorithmVersion: .v1Basic,
            rangeStart: CycleMath.addDays(predictedStart, -rangeDays),
            rangeEnd: CycleMath.addDays(predictedStart, rangeDays),
            basedOnCycles: 0
        )
    }

    // MARK: - V2: Weighted Moving Average

    /// Exponential WMA with alpha=0.7 (recent cycles weighted more heavily).
    private static func predictV2(
        cycles: [CycleInput],
        profile: ProfileInput,
        hasSymptomData: Bool
    ) -> PredictionResult {
        let lengths = extractCycleLengths(cycles, fallbackLength: profile.avgCycleLength)
        guard lengths.count >= 2 else {
            return predictV1(profile: profile, lastPeriod: cycles.first?.startDate)
        }

        let predictedLength = exponentialWMA(lengths, alpha: 0.7)
        let mostRecent = cycles[0].startDate
        let predictedStart = CycleMath.addDays(mostRecent, Int(round(predictedLength)))
        let predictedEnd = CycleMath.addDays(predictedStart, profile.avgBleedingDays - 1)

        let sd = CycleMath.stdDev(lengths)
        let confidence = CycleMath.calculateConfidence(
            cycleCount: lengths.count, regularity: profile.cycleRegularity,
            hasSymptomData: hasSymptomData, stdDev: sd
        )
        let rangeDays = CycleMath.predictionRangeDays(confidence: confidence, stdDev: sd)

        let fertileWindow = CycleMath.simpleFertileWindow(
            cycleStart: predictedStart, cycleLength: Int(round(predictedLength))
        )

        return PredictionResult(
            predictedStart: predictedStart,
            predictedEnd: predictedEnd,
            fertileWindow: fertileWindow,
            confidence: confidence,
            algorithmVersion: .v2Statistical,
            rangeStart: CycleMath.addDays(predictedStart, -rangeDays),
            rangeEnd: CycleMath.addDays(predictedStart, rangeDays),
            basedOnCycles: lengths.count
        )
    }

    // MARK: - V3: Historical + Ogino-Knaus

    /// WMA + trend detection + age adjustment + Ogino-Knaus fertile window.
    private static func predictV3(
        cycles: [CycleInput],
        profile: ProfileInput,
        age: Int?,
        hasSymptomData: Bool
    ) -> PredictionResult {
        let lengths = extractCycleLengths(cycles, fallbackLength: profile.avgCycleLength)
        guard lengths.count >= 3 else {
            return predictV2(cycles: cycles, profile: profile, hasSymptomData: hasSymptomData)
        }

        // Base prediction: trimmed WMA for irregular, regular WMA otherwise
        var predictedLength: Double
        if profile.cycleRegularity == "irregular", lengths.count >= 4 {
            predictedLength = trimmedWMA(lengths, alpha: 0.7)
        } else {
            predictedLength = exponentialWMA(lengths, alpha: 0.7)
        }

        // Trend adjustment
        let trend = CycleMath.detectTrend(lengths)
        if trend != 0 {
            predictedLength += trend > 0 ? 0.5 : -0.5
        }

        // Age adjustment
        if let userAge = age {
            let ageVariation = CycleMath.ageVariationFactor(age: userAge)
            predictedLength += ageVariation * 0.3
        }

        let mostRecent = cycles[0].startDate
        let roundedLength = Int(round(predictedLength))
        let predictedStart = CycleMath.addDays(mostRecent, roundedLength)
        let predictedEnd = CycleMath.addDays(predictedStart, profile.avgBleedingDays - 1)

        let sd = CycleMath.stdDev(lengths)
        let confidence = CycleMath.calculateConfidence(
            cycleCount: lengths.count, regularity: profile.cycleRegularity,
            hasSymptomData: hasSymptomData, stdDev: sd
        )
        let rangeDays = CycleMath.predictionRangeDays(confidence: confidence, stdDev: sd)

        // Ogino-Knaus fertile window (3+ cycles required)
        let fertileWindow = CycleMath.oginoKnausFertileWindow(
            cycleStart: predictedStart, cycleLengths: lengths
        )

        return PredictionResult(
            predictedStart: predictedStart,
            predictedEnd: predictedEnd,
            fertileWindow: fertileWindow,
            confidence: confidence,
            algorithmVersion: .v3Historical,
            rangeStart: CycleMath.addDays(predictedStart, -rangeDays),
            rangeEnd: CycleMath.addDays(predictedStart, rangeDays),
            basedOnCycles: lengths.count
        )
    }

    // MARK: - V4: ML + Pattern Detection

    /// V3 base + confirmation learning + seasonal patterns + bias correction.
    private static func predictV4(
        cycles: [CycleInput],
        profile: ProfileInput,
        age: Int?,
        hasSymptomData: Bool
    ) -> PredictionResult {
        guard cycles.count >= 6 else {
            return predictV3(
                cycles: cycles, profile: profile,
                age: age, hasSymptomData: hasSymptomData
            )
        }

        // Start with V3 as base
        var base = predictV3(
            cycles: cycles, profile: profile,
            age: age, hasSymptomData: hasSymptomData
        )

        let lengths = extractCycleLengths(cycles, fallbackLength: profile.avgCycleLength)

        // Enhancement 1: Confirmation learning
        let confirmationAdj = analyzeConfirmationAccuracy(cycles)

        // Enhancement 2: Seasonal pattern detection
        let seasonalAdj = detectSeasonalPattern(cycles: cycles, cycleLengths: lengths)

        // Enhancement 3: Bias correction from recent deviations
        let biasAdj = calculateBiasCorrection(cycles)

        let totalAdjustment = confirmationAdj + seasonalAdj + biasAdj
        let adjustedDays = Int(round(totalAdjustment))

        if adjustedDays != 0 {
            base.predictedStart = CycleMath.addDays(base.predictedStart, adjustedDays)
            base.predictedEnd = CycleMath.addDays(base.predictedEnd, adjustedDays)
            base.rangeStart = CycleMath.addDays(base.rangeStart, adjustedDays)
            base.rangeEnd = CycleMath.addDays(base.rangeEnd, adjustedDays)

            // Recompute fertile window for adjusted date
            base.fertileWindow = CycleMath.oginoKnausFertileWindow(
                cycleStart: base.predictedStart, cycleLengths: lengths
            )
        }

        // Confidence boost from confirmed cycles
        var boostedConfidence = base.confidence
        let confirmedCount = cycles.filter(\.isConfirmed).count
        let confirmedRatio = Double(confirmedCount) / Double(cycles.count)
        if confirmedRatio >= 0.8 {
            boostedConfidence += 0.05
        } else if confirmedRatio >= 0.5 {
            boostedConfidence += 0.03
        }
        base.confidence = min(0.95, boostedConfidence)
        base.algorithmVersion = .v4ML

        return base
    }

    // MARK: - Internal Algorithms

    /// Exponential Weighted Moving Average. Alpha=0.7 means recent values dominate.
    private static func exponentialWMA(_ lengths: [Int], alpha: Double) -> Double {
        guard !lengths.isEmpty else { return 28 }
        var weightedSum = 0.0
        var totalWeight = 0.0

        for (i, length) in lengths.enumerated() {
            let weight = pow(alpha, Double(i))
            weightedSum += Double(length) * weight
            totalWeight += weight
        }

        return totalWeight > 0 ? weightedSum / totalWeight : Double(lengths[0])
    }

    /// Trimmed WMA: remove min and max outliers, then apply exponential WMA.
    private static func trimmedWMA(_ lengths: [Int], alpha: Double) -> Double {
        guard lengths.count >= 4 else { return exponentialWMA(lengths, alpha: alpha) }
        var sorted = lengths.sorted()
        sorted.removeFirst()
        sorted.removeLast()
        return exponentialWMA(sorted, alpha: alpha)
    }

    /// Extract physiologically valid cycle lengths (18-50 days) from history.
    /// Falls back to profile average if no valid lengths found.
    private static func extractCycleLengths(
        _ cycles: [CycleInput],
        fallbackLength: Int
    ) -> [Int] {
        // Use stored cycle length if available, otherwise calculate from consecutive start dates
        var lengths: [Int] = []

        for i in 0..<(cycles.count - 1) {
            if let stored = cycles[i].actualCycleLength {
                lengths.append(stored)
            } else {
                let gap = CycleMath.cycleLength(
                    periodStart1: cycles[i + 1].startDate,
                    periodStart2: cycles[i].startDate
                )
                if gap >= 18, gap <= 50 {
                    lengths.append(gap)
                }
            }
        }

        // If no valid lengths, use profile average
        if lengths.isEmpty, fallbackLength >= 18, fallbackLength <= 50 {
            lengths.append(fallbackLength)
        }

        return lengths
    }

    // MARK: V4 Enhancements

    /// Learn from past prediction errors to improve accuracy.
    private static func analyzeConfirmationAccuracy(_ cycles: [CycleInput]) -> Double {
        let confirmed = cycles.filter { $0.isConfirmed && $0.actualDeviationDays != nil }
        guard !confirmed.isEmpty else { return 0 }

        let totalDeviation = confirmed.compactMap(\.actualDeviationDays).reduce(0, +)
        let avgDeviation = Double(totalDeviation) / Double(confirmed.count)
        return -avgDeviation // Negative because we correct for the bias
    }

    /// Detect monthly/seasonal patterns in cycle lengths.
    private static func detectSeasonalPattern(
        cycles: [CycleInput],
        cycleLengths: [Int]
    ) -> Double {
        guard cycleLengths.count >= 4 else { return 0 }

        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())

        // Group lengths by start month
        var monthLengths: [Int: [Int]] = [:]
        for (i, cycle) in cycles.enumerated() where i < cycleLengths.count {
            let month = calendar.component(.month, from: cycle.startDate)
            monthLengths[month, default: []].append(cycleLengths[i])
        }

        guard let currentMonthLengths = monthLengths[currentMonth], !currentMonthLengths.isEmpty else {
            return 0
        }

        let monthAvg = CycleMath.mean(currentMonthLengths)
        let overallAvg = CycleMath.mean(cycleLengths)
        return monthAvg - overallAvg
    }

    /// Correct recent prediction bias: weight recent deviations at 70%.
    private static func calculateBiasCorrection(_ cycles: [CycleInput]) -> Double {
        let recentConfirmed = cycles.prefix(3).filter {
            $0.isConfirmed && $0.actualDeviationDays != nil
        }
        guard !recentConfirmed.isEmpty else { return 0 }

        let recentDeviations = recentConfirmed.compactMap(\.actualDeviationDays)
        let avgRecent = Double(recentDeviations.reduce(0, +)) / Double(recentDeviations.count)
        return -avgRecent * 0.7
    }
}

// MARK: - Input / Output Types

public struct CycleInput: Sendable, Equatable {
    public let startDate: Date
    public let actualCycleLength: Int?
    public let isConfirmed: Bool
    public let actualDeviationDays: Int?

    public init(
        startDate: Date,
        actualCycleLength: Int? = nil,
        isConfirmed: Bool = true,
        actualDeviationDays: Int? = nil
    ) {
        self.startDate = startDate
        self.actualCycleLength = actualCycleLength
        self.isConfirmed = isConfirmed
        self.actualDeviationDays = actualDeviationDays
    }
}

public struct ProfileInput: Sendable, Equatable {
    public let avgCycleLength: Int
    public let avgBleedingDays: Int
    public let cycleRegularity: String

    public init(avgCycleLength: Int = 28, avgBleedingDays: Int = 5, cycleRegularity: String = "unknown") {
        self.avgCycleLength = avgCycleLength
        self.avgBleedingDays = avgBleedingDays
        self.cycleRegularity = cycleRegularity
    }
}

public struct PredictionResult: Sendable, Equatable {
    public var predictedStart: Date
    public var predictedEnd: Date
    public var fertileWindow: FertileWindow
    public var confidence: Double
    public var algorithmVersion: AlgorithmVersion
    public var rangeStart: Date
    public var rangeEnd: Date
    public let basedOnCycles: Int
}

public enum AlgorithmVersion: String, Sendable, Equatable {
    case v1Basic = "v1_basic"
    case v2Statistical = "v2_statistical"
    case v3Historical = "v3_historical"
    case v4ML = "v4_ml"

    public var displayName: String {
        switch self {
        case .v1Basic: "Basic"
        case .v2Statistical: "Statistical"
        case .v3Historical: "Historical"
        case .v4ML: "Adaptive"
        }
    }
}
