import Foundation

// MARK: - Body Signals
//
// Snapshot of the user's Apple Watch / HealthKit biometrics correlated
// with their menstrual cycle phases. Lives purely as a value type: the
// HealthKit client returns an instance, the UI renders it. No
// mid-render HKQuery work, no async hops once the snapshot is in state.

public struct BodySignalsSnapshot: Equatable, Sendable {
    /// When the snapshot was produced. Used by the UI to show a
    /// "Updated a minute ago" line and to decide if we should re-fetch
    /// on re-appear.
    public let capturedAt: Date

    /// The user's phase for "today" — drives the headline badge and
    /// the "current vs other phases" comparisons on the detail sheet.
    /// `nil` only when we don't have enough cycle history to classify.
    public let phase: CyclePhase?

    public let wristTemperature: BodySignalMetric?
    public let hrv: BodySignalMetric?
    public let restingHR: BodySignalMetric?

    public let permission: PermissionState

    public init(
        capturedAt: Date,
        phase: CyclePhase?,
        wristTemperature: BodySignalMetric?,
        hrv: BodySignalMetric?,
        restingHR: BodySignalMetric?,
        permission: PermissionState
    ) {
        self.capturedAt = capturedAt
        self.phase = phase
        self.wristTemperature = wristTemperature
        self.hrv = hrv
        self.restingHR = restingHR
        self.permission = permission
    }

    /// Tri-state authorization read-out. `.partial` is the common case
    /// when the user grants some types and declines others — we still
    /// render the granted ones and show per-card empty states for the
    /// missing ones.
    public enum PermissionState: String, Equatable, Sendable {
        case undetermined   // never asked
        case partial        // some types granted
        case granted        // all three types granted
        case denied         // explicitly declined all relevant types
        case unavailable    // device without HealthKit (iPad / Mac)
    }

    /// Lightweight "no signals yet" factory used by the skeleton and
    /// by previews.
    public static func empty(phase: CyclePhase? = nil) -> BodySignalsSnapshot {
        BodySignalsSnapshot(
            capturedAt: Date(),
            phase: phase,
            wristTemperature: nil,
            hrv: nil,
            restingHR: nil,
            permission: .undetermined
        )
    }
}

// MARK: - Metric

/// One biometric — wrist temperature, HRV, or resting HR. The shape
/// is intentionally uniform so the teaser row and the detail sheet
/// card can share rendering code.
public struct BodySignalMetric: Equatable, Sendable {
    public let kind: Kind
    /// Daily (or nightly) readings for this metric, oldest → newest.
    /// The detail sheet renders the full series; the teaser uses only
    /// the last value + the personal baseline.
    public let samples: [BodySignalSample]
    /// Mean across the full sample window, used as the personal
    /// baseline for delta arrows ("↑ 3 from baseline").
    public let baseline: Double?
    /// Mean across samples whose phase matched the user's current
    /// phase at capture time. Anchors the phase-relative comparison
    /// on the HRV / RHR cards.
    public let currentPhaseAvg: Double?
    /// Mean per phase across the entire sample window. Drives the
    /// "HRV by phase" bar chart on the detail sheet.
    public let byPhase: [CyclePhase: Double]
    /// The unit string we display next to numbers — e.g. "°C", "ms",
    /// "bpm". Set by the client once the user's locale / body temp
    /// preference is resolved.
    public let unit: String
    /// True if this type had *any* non-zero samples in the window.
    /// Distinct from "authorization granted but no data yet" — the UI
    /// uses this to decide between a real value and an empty state.
    public let hasData: Bool
    /// True if we have authorization but Apple hasn't surfaced any
    /// data yet (e.g. user just enabled Sleep on a Series 8 watch
    /// but hasn't slept with it on). Distinguishes "waiting on first
    /// read" from "user denied".
    public let awaitingFirstSample: Bool

    public init(
        kind: Kind,
        samples: [BodySignalSample],
        baseline: Double?,
        currentPhaseAvg: Double?,
        byPhase: [CyclePhase: Double],
        unit: String,
        hasData: Bool,
        awaitingFirstSample: Bool
    ) {
        self.kind = kind
        self.samples = samples
        self.baseline = baseline
        self.currentPhaseAvg = currentPhaseAvg
        self.byPhase = byPhase
        self.unit = unit
        self.hasData = hasData
        self.awaitingFirstSample = awaitingFirstSample
    }

    /// Stable identifier used by the UI to route per-metric info taps
    /// and to render icons / titles without switching on associated
    /// values.
    public enum Kind: String, Equatable, Sendable, CaseIterable {
        case wristTemperature
        case hrv
        case restingHR
    }

    /// Latest reading, if any — `samples.last`.
    public var latest: BodySignalSample? { samples.last }

    /// Latest − baseline. `nil` when either side is missing.
    public var latestDelta: Double? {
        guard let last = latest?.value, let baseline else { return nil }
        return last - baseline
    }
}

// MARK: - Sample

public struct BodySignalSample: Equatable, Sendable, Identifiable {
    public let id: Date
    public let date: Date
    public let value: Double
    /// Phase resolved for the sample's day. `nil` if the sample fell
    /// outside the cycle history we could classify (e.g. a reading
    /// from before the user logged any cycles).
    public let phase: CyclePhase?

    public init(date: Date, value: Double, phase: CyclePhase?) {
        self.id = date
        self.date = date
        self.value = value
        self.phase = phase
    }
}

// MARK: - Errors

/// Sendable failure the client can surface back to the reducer — not
/// every HealthKit miss is "no permission", so we distinguish a few
/// states the UI actually renders differently.
public enum BodySignalsError: Error, Equatable, Sendable {
    case healthKitUnavailable
    case noPermission
    case readFailed(String)
}
