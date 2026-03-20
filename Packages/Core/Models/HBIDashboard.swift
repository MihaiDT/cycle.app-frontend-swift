import Foundation

// MARK: - Dashboard Response

public struct HBIDashboardResponse: Codable, Equatable, Sendable {
    public let today: HBIScore?
    public let weekTrend: [HBIScore]?
    public let latestReport: DailySelfReport?
    public let cyclePhase: String?
    public let cycleDay: Int?
    public let insights: [String]?

    public init(
        today: HBIScore? = nil,
        weekTrend: [HBIScore] = [],
        latestReport: DailySelfReport? = nil,
        cyclePhase: String? = nil,
        cycleDay: Int? = nil,
        insights: [String] = []
    ) {
        self.today = today
        self.weekTrend = weekTrend
        self.latestReport = latestReport
        self.cyclePhase = cyclePhase
        self.cycleDay = cycleDay
        self.insights = insights
    }
}

// MARK: - Today Response

public struct HBITodayResponse: Codable, Equatable, Sendable {
    public let hbiScore: HBIScore?
    public let selfReport: DailySelfReport?
    public let hasData: Bool
    public let message: String

    public init(
        hbiScore: HBIScore? = nil,
        selfReport: DailySelfReport? = nil,
        hasData: Bool = false,
        message: String = ""
    ) {
        self.hbiScore = hbiScore
        self.selfReport = selfReport
        self.hasData = hasData
        self.message = message
    }
}

// MARK: - Daily Report Request

public struct DailyReportRequest: Encodable, Equatable, Sendable {
    public let energyLevel: Int
    public let stressLevel: Int
    public let sleepQuality: Int
    public let moodLevel: Int
    public let notes: String?

    public init(
        energyLevel: Int,
        stressLevel: Int,
        sleepQuality: Int,
        moodLevel: Int,
        notes: String? = nil
    ) {
        self.energyLevel = max(1, min(5, energyLevel))
        self.stressLevel = max(1, min(5, stressLevel))
        self.sleepQuality = max(1, min(5, sleepQuality))
        self.moodLevel = max(1, min(5, moodLevel))
        self.notes = notes
    }
}

// MARK: - Daily Report Response

public struct DailyReportResponse: Codable, Equatable, Sendable {
    public let report: DailySelfReport
    public let hbiScore: HBIScore?
    public let message: String

    public init(
        report: DailySelfReport,
        hbiScore: HBIScore? = nil,
        message: String = ""
    ) {
        self.report = report
        self.hbiScore = hbiScore
        self.message = message
    }
}

// MARK: - Cycle Phase

public enum CyclePhase: String, Codable, Equatable, Sendable, CaseIterable {
    case menstrual
    case follicular
    case ovulatory
    case luteal

    public var displayName: String {
        switch self {
        case .menstrual: "Menstrual"
        case .follicular: "Follicular"
        case .ovulatory: "Ovulatory"
        case .luteal: "Luteal"
        }
    }

    public var insight: String {
        switch self {
        case .menstrual: "Rest and gentle movement are key during this phase."
        case .follicular: "Great time for new activities and challenges!"
        case .ovulatory: "You may feel more social and energetic."
        case .luteal: "Focus on self-care and gentle routines."
        }
    }

    public var icon: String {
        switch self {
        case .menstrual: "moon.stars"
        case .follicular: "leaf"
        case .ovulatory: "sun.max"
        case .luteal: "cloud.sun"
        }
    }

    public var emoji: String {
        switch self {
        case .menstrual: "🩸"
        case .follicular: "🌸"
        case .ovulatory: "✨"
        case .luteal: "🌙"
        }
    }

    public var description: String {
        switch self {
        case .menstrual: "Rest & restore"
        case .follicular: "Rising energy"
        case .ovulatory: "Peak vitality"
        case .luteal: "Wind down"
        }
    }

    /// Medical description with hormonal context
    public var medicalDescription: String {
        switch self {
        case .menstrual:
            return "Estrogen & progesterone are at their lowest. The uterine lining sheds. Rest, warmth, and iron-rich foods support recovery."
        case .follicular:
            return "FSH stimulates follicle growth. Estrogen rises gradually — boosting energy, focus, and mood. Great time for new challenges."
        case .ovulatory:
            return "LH surge triggers egg release. Estrogen peaks — expect peak confidence, libido, and communication skills. Fertile window active."
        case .luteal:
            return "Progesterone rises to prepare the uterus. If no pregnancy occurs, both hormones drop, which can trigger PMS in the final days."
        }
    }

    /// Typical day ranges within a cycle, using actual bleeding days
    public func dayRange(cycleLength: Int, bleedingDays: Int = 5) -> ClosedRange<Int> {
        let bleedingDays = max(1, bleedingDays)
        let ovulationDay = cycleLength - 14
        switch self {
        case .menstrual: return 1...bleedingDays
        case .follicular: return (bleedingDays + 1)...(ovulationDay - 2)
        case .ovulatory: return (ovulationDay - 1)...(ovulationDay + 1)
        case .luteal: return (ovulationDay + 2)...cycleLength
        }
    }
}

// MARK: - Flow Intensity

/// Menstrual flow intensity for period day logging
public enum FlowIntensity: String, Codable, Equatable, Sendable, CaseIterable {
    case spotting = "spotting"
    case light = "light"
    case medium = "medium"
    case heavy = "heavy"

    public var label: String {
        switch self {
        case .spotting: "Spotting"
        case .light: "Light"
        case .medium: "Medium"
        case .heavy: "Heavy"
        }
    }

    /// Number of filled droplet icons to show (0 = small dot for spotting)
    public var dropletCount: Int {
        switch self {
        case .spotting: 0
        case .light: 1
        case .medium: 2
        case .heavy: 3
        }
    }
}
