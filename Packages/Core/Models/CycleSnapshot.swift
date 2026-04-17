import Foundation

// MARK: - Cycle Snapshot

/// Snapshot of cycle-derived calendar data for a given time window.
///
/// Owned by `TodayFeature` (the data root), propagated to `CalendarFeature`
/// and `EditPeriodFeature` on demand. Consumers read fields directly.
///
/// Unifies previously-duplicated state that was scattered across three
/// reducers (`serverPeriodDays`/`serverPredictedDays`/`serverFertileDays`/
/// `serverOvulationDays` on `TodayFeature`; `periodDays`/`predictedPeriodDays`/
/// `fertileDays`/`ovulationDays`/`periodFlowIntensity` on `CalendarFeature`
/// and `EditPeriodFeature`). Single source of truth eliminates the race
/// conditions flagged in the audit.
public struct CycleSnapshot: Equatable, Sendable {
    /// Confirmed + predicted period day keys ("yyyy-MM-dd")
    public var periodDays: Set<String>
    /// Predicted day keys (subset of `periodDays` that are prediction, not confirmed)
    public var predictedDays: Set<String>
    /// Fertile days with level (keys: "yyyy-MM-dd")
    public var fertileDays: [String: FertilityLevel]
    /// Ovulation day keys (keys: "yyyy-MM-dd")
    public var ovulationDays: Set<String>
    /// Per-day flow intensity (used by Calendar + EditPeriod rendering;
    /// Today doesn't care but keeps it centralized).
    public var flowIntensity: [String: FlowIntensity]

    public init(
        periodDays: Set<String> = [],
        predictedDays: Set<String> = [],
        fertileDays: [String: FertilityLevel] = [:],
        ovulationDays: Set<String> = [],
        flowIntensity: [String: FlowIntensity] = [:]
    ) {
        self.periodDays = periodDays
        self.predictedDays = predictedDays
        self.fertileDays = fertileDays
        self.ovulationDays = ovulationDays
        self.flowIntensity = flowIntensity
    }

    public static let empty = CycleSnapshot()
}
