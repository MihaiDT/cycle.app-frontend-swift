import ComposableArchitecture
import Foundation
import HealthKit
import SwiftData

// MARK: - HealthKit Local Client
//
// Reads Apple Watch biometrics (wrist temperature, HRV, resting HR)
// through HealthKit and correlates each sample with the user's cycle
// phase. The client stays stateless — every `fetchBodySignals` call
// runs fresh HKSampleQueries against the user's Health data; no
// caching. A UI card that needs an updated snapshot just calls again.
//
// We deliberately don't use HKObserverQuery / background delivery
// here. The stats screen is user-initiated, not ambient; pulling on
// demand keeps permission surface area small and the code easier to
// reason about.

public struct HealthKitLocalClient: Sendable {
    /// Probe the device + app capability and the user's current
    /// authorization state for the three biometric types we read.
    /// Returns synchronously because HealthKit exposes this without a
    /// query — lets the UI decide between "show CTA" and "go fetch"
    /// before committing to an expensive read.
    public var authorizationProbe: @Sendable () -> BodySignalsAuthProbe

    /// Request read access for wrist temp + HRV + resting HR. Safe to
    /// call repeatedly — HealthKit only surfaces the system prompt for
    /// types the user hasn't decided on yet. Returns once the sheet
    /// dismisses (or immediately if nothing was pending).
    public var requestAuthorization: @Sendable () async throws -> Void

    /// Build a full `BodySignalsSnapshot` — runs the three HKSampleQueries,
    /// pulls the current cycle context from SwiftData, classifies every
    /// sample by phase, and assembles the aggregates the teaser + sheet
    /// both render from.
    public var fetchBodySignals: @Sendable () async throws -> BodySignalsSnapshot
}

// MARK: - Auth Probe

/// Narrow read-out of authorization + device state. Drives the teaser
/// card's decision to show the CTA vs. actual data.
public enum BodySignalsAuthProbe: Equatable, Sendable {
    case unavailable           // no HealthKit (iPad / Mac)
    case needsPrompt           // at least one type is .notDetermined
    case canProceed            // every type has been decided — try fetching
}

// MARK: - Dependency

extension HealthKitLocalClient: DependencyKey {
    public static let liveValue = HealthKitLocalClient.live()
    public static let testValue = HealthKitLocalClient.mock()
    public static let previewValue = HealthKitLocalClient.mock()
}

extension DependencyValues {
    public var healthKitLocal: HealthKitLocalClient {
        get { self[HealthKitLocalClient.self] }
        set { self[HealthKitLocalClient.self] = newValue }
    }
}

// MARK: - Live

extension HealthKitLocalClient {
    /// Days of history we pull for every metric. 90 covers roughly 3
    /// cycles for a 28-day user — enough to stabilize per-phase means
    /// without dragging in stale data from half a year ago.
    fileprivate static let windowDays: Int = 90

    static func live() -> Self {
        HealthKitLocalClient(
            authorizationProbe: {
                guard HKHealthStore.isHealthDataAvailable() else {
                    return .unavailable
                }
                let store = HKHealthStore()
                let types = Self.readTypes()
                let anyUndetermined = types.contains { store.authorizationStatus(for: $0) == .notDetermined }
                return anyUndetermined ? .needsPrompt : .canProceed
            },

            requestAuthorization: {
                guard HKHealthStore.isHealthDataAvailable() else {
                    throw BodySignalsError.healthKitUnavailable
                }
                let store = HKHealthStore()
                let read = Set(Self.readTypes())
                // `requestAuthorization(toShare:read:)` is the modern
                // async entry — it suspends until the system sheet
                // dismisses and is a no-op for types already decided.
                try await store.requestAuthorization(toShare: [], read: read)
            },

            fetchBodySignals: {
                guard HKHealthStore.isHealthDataAvailable() else {
                    throw BodySignalsError.healthKitUnavailable
                }
                return try await Self.buildSnapshot()
            }
        )
    }

    // MARK: Read types

    /// The three quantity types this feature depends on. Written as a
    /// function so we can keep using force-unwraps safely (these
    /// identifiers exist on every iOS 16+ deployment target we support).
    private static func readTypes() -> [HKObjectType] {
        var types: [HKObjectType] = []
        if #available(iOS 16.0, *),
           let wrist = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
            types.append(wrist)
        }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.append(hrv)
        }
        if let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.append(rhr)
        }
        return types
    }

    // MARK: Snapshot assembly

    /// Pull all three metrics in parallel, pair every sample with its
    /// phase, and roll up into a `BodySignalsSnapshot`. Any individual
    /// metric that throws is treated as "missing" — the other two
    /// still render.
    private static func buildSnapshot() async throws -> BodySignalsSnapshot {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .day, value: -windowDays, to: cal.startOfDay(for: now))
            ?? now

        // Cycle context from SwiftData — we need the cycle start + length
        // + bleeding days to classify each sample's phase. If the user
        // has no cycles yet, phases are nil and per-phase aggregates stay
        // empty (the UI falls back to baseline-only comparisons).
        let cycleClassifier = try? loadCycleClassifier()

        async let wrist = fetchMetric(
            kind: .wristTemperature,
            start: start,
            end: now,
            classifier: cycleClassifier
        )
        async let hrv = fetchMetric(
            kind: .hrv,
            start: start,
            end: now,
            classifier: cycleClassifier
        )
        async let rhr = fetchMetric(
            kind: .restingHR,
            start: start,
            end: now,
            classifier: cycleClassifier
        )

        let wristResult = try? await wrist
        let hrvResult = try? await hrv
        let rhrResult = try? await rhr

        let granted = [wristResult, hrvResult, rhrResult].compactMap { $0 }
        let permission: BodySignalsSnapshot.PermissionState = {
            if granted.isEmpty { return .denied }
            let withData = granted.filter(\.hasData)
            if withData.count == 3 { return .granted }
            if withData.isEmpty { return .denied }
            return .partial
        }()

        let todayPhase = cycleClassifier?.phase(for: now) ?? nil

        return BodySignalsSnapshot(
            capturedAt: now,
            phase: todayPhase,
            wristTemperature: wristResult,
            hrv: hrvResult,
            restingHR: rhrResult,
            permission: permission
        )
    }

    // MARK: Metric query

    /// Build a `BodySignalMetric` for a single type. Runs a single
    /// HKSampleQuery over the window, collapses multiple intraday
    /// readings to a daily mean (HRV can have 10-20 per day), then
    /// folds samples into per-phase means via the classifier.
    private static func fetchMetric(
        kind: BodySignalMetric.Kind,
        start: Date,
        end: Date,
        classifier: CycleClassifier?
    ) async throws -> BodySignalMetric {
        guard let (type, unit, unitLabel) = quantityDescriptor(for: kind) else {
            return emptyMetric(kind: kind)
        }

        let samples = try await runSampleQuery(type: type, start: start, end: end)
        let dailyValues = collapseToDailyMean(samples: samples, unit: unit)

        let readings: [BodySignalSample] = dailyValues.map { day, value in
            BodySignalSample(
                date: day,
                value: value,
                phase: classifier?.phase(for: day) ?? nil
            )
        }
        .sorted { $0.date < $1.date }

        guard !readings.isEmpty else {
            return BodySignalMetric(
                kind: kind,
                samples: [],
                baseline: nil,
                currentPhaseAvg: nil,
                byPhase: [:],
                unit: unitLabel,
                hasData: false,
                awaitingFirstSample: true
            )
        }

        let baseline = mean(readings.map(\.value))
        let todayPhase = classifier?.phase(for: end) ?? nil
        let phaseGroups = Dictionary(grouping: readings) { $0.phase }
        var byPhase: [CyclePhase: Double] = [:]
        for (phase, bucket) in phaseGroups {
            guard let phase else { continue }
            byPhase[phase] = mean(bucket.map(\.value))
        }
        let currentPhaseAvg = todayPhase.flatMap { byPhase[$0] }

        return BodySignalMetric(
            kind: kind,
            samples: readings,
            baseline: baseline,
            currentPhaseAvg: currentPhaseAvg,
            byPhase: byPhase,
            unit: unitLabel,
            hasData: true,
            awaitingFirstSample: false
        )
    }

    /// HealthKit quantity type + its canonical unit for each metric.
    /// Centralized so the read types in `requestAuthorization` and the
    /// actual query types always match.
    private static func quantityDescriptor(
        for kind: BodySignalMetric.Kind
    ) -> (type: HKQuantityType, unit: HKUnit, label: String)? {
        switch kind {
        case .wristTemperature:
            if #available(iOS 16.0, *),
               let type = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
                return (type, .degreeCelsius(), "°C")
            }
            return nil
        case .hrv:
            if let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
                return (type, HKUnit.secondUnit(with: .milli), "ms")
            }
            return nil
        case .restingHR:
            if let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
                return (type, HKUnit.count().unitDivided(by: .minute()), "bpm")
            }
            return nil
        }
    }

    private static func emptyMetric(kind: BodySignalMetric.Kind) -> BodySignalMetric {
        BodySignalMetric(
            kind: kind,
            samples: [],
            baseline: nil,
            currentPhaseAvg: nil,
            byPhase: [:],
            unit: "",
            hasData: false,
            awaitingFirstSample: true
        )
    }

    // MARK: Query runner

    /// Wraps the completion-handler HKSampleQuery in an async call.
    /// Returns an empty array on auth denial — HealthKit surfaces that
    /// as "no samples" rather than an error, which matches the UX we
    /// want (denied + authorized-with-no-watch look the same).
    private static func runSampleQuery(
        type: HKQuantityType,
        start: Date,
        end: Date
    ) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: .strictStartDate
            )
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sort
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            HKHealthStore().execute(query)
        }
    }

    // MARK: Aggregation helpers

    /// HRV often has multiple readings per day; RHR and wrist temp are
    /// typically one per day. Collapsing to daily means up-front keeps
    /// downstream aggregation and per-phase bucketing honest — a phase
    /// with 3 observed days and 30 HRV samples shouldn't out-weigh a
    /// phase with 4 days and 4 samples.
    private static func collapseToDailyMean(
        samples: [HKQuantitySample],
        unit: HKUnit
    ) -> [(day: Date, value: Double)] {
        let cal = Calendar.current
        var buckets: [Date: [Double]] = [:]
        for sample in samples {
            let day = cal.startOfDay(for: sample.startDate)
            let value = sample.quantity.doubleValue(for: unit)
            buckets[day, default: []].append(value)
        }
        return buckets
            .map { (day, vals) in (day: day, value: mean(vals)) }
            .sorted { $0.day < $1.day }
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: Cycle classifier

    /// Pulls the cycle start + length + bleeding days once and serves
    /// `phase(for:)` lookups without touching SwiftData again per
    /// sample. Written on top of `CycleMath.cyclePhase` so the phase
    /// classification matches the rest of the app (Home, Calendar,
    /// HBI) — consistent rules, consistent boundaries.
    fileprivate struct CycleClassifier {
        let cycleStart: Date
        let cycleLength: Int
        let bleedingDays: Int

        func phase(for date: Date) -> CyclePhase? {
            let day = CycleMath.cycleDay(cycleStart: cycleStart, date: date)
            // `cyclePhase` accepts any day number including negatives
            // (from before the latest logged cycle). For those we walk
            // the day back into [1, cycleLength] so the phase buckets
            // stay meaningful across 3 cycles of history.
            let wrapped = ((day - 1) % cycleLength + cycleLength) % cycleLength + 1
            let result = CycleMath.cyclePhase(
                cycleDay: wrapped,
                cycleLength: cycleLength,
                bleedingDays: bleedingDays
            )
            return CyclePhase(rawValue: result.rawValue)
        }
    }

    /// Build the classifier from SwiftData. Mirrors the pattern used
    /// by `HBILocalClient.currentCycleContext` so phase decisions stay
    /// aligned across features.
    private static func loadCycleClassifier() throws -> CycleClassifier {
        let container = CycleDataStore.shared
        let context = ModelContext(container)

        let cycleDescriptor = FetchDescriptor<CycleRecord>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        guard let latestCycle = try context.fetch(cycleDescriptor).first else {
            throw BodySignalsError.readFailed("no cycle history")
        }

        let profileDescriptor = FetchDescriptor<MenstrualProfileRecord>()
        let profile = try context.fetch(profileDescriptor).first

        let cycleLength = profile?.avgCycleLength ?? 28
        let bleedingDays = latestCycle.bleedingDays ?? profile?.avgBleedingDays ?? 5

        return CycleClassifier(
            cycleStart: latestCycle.startDate,
            cycleLength: cycleLength,
            bleedingDays: bleedingDays
        )
    }
}

// MARK: - Mock

extension HealthKitLocalClient {
    static func mock() -> Self {
        HealthKitLocalClient(
            authorizationProbe: { .canProceed },
            requestAuthorization: {},
            fetchBodySignals: { .empty() }
        )
    }
}
