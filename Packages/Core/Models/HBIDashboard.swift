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
        case .menstrual: "Your body is asking for stillness. Honor the quiet."
        case .follicular: "Something new is waking up inside you. Follow it."
        case .ovulatory: "You're radiating. This is your moment to shine."
        case .luteal: "Your inner critic is actually your inner editor. Use it wisely."
        }
    }

    public var icon: String {
        switch self {
        case .menstrual: "moon.stars.fill"
        case .follicular: "leaf.fill"
        case .ovulatory: "sun.max.fill"
        case .luteal: "wind"
        }
    }

    public var emoji: String {
        switch self {
        case .menstrual: "🌙"
        case .follicular: "🌱"
        case .ovulatory: "☀️"
        case .luteal: "🍂"
        }
    }

    public var description: String {
        switch self {
        case .menstrual: "Retreat, rest, release"
        case .follicular: "Renewal, rising energy"
        case .ovulatory: "Peak radiance, magnetism"
        case .luteal: "Reflection, slowing down"
        }
    }

    /// Deeper context for each phase
    public var medicalDescription: String {
        switch self {
        case .menstrual:
            return "Your energy is at its lowest — and that's by design. This is your body's reset. Rest, warmth, and nourishing foods help you rebuild for the cycle ahead."
        case .follicular:
            return "Your energy is climbing day by day. Your mind is sharper, your mood is lifting, and new ideas come easily. Plant seeds now — creative and literal."
        case .ovulatory:
            return "Everything peaks here — confidence, communication, presence. People are drawn to you. Use these days for what matters most."
        case .luteal:
            return "You're turning inward. Your tolerance for nonsense drops, your attention to detail rises. This isn't negativity — it's clarity. Finish what you started."
        }
    }

    /// Typical day ranges within a cycle, using actual bleeding days.
    /// Boundaries are clamped so that ranges never crash for short cycles.
    /// The backend uses `ovDay = max(10, cycleLength - 14)` — we mirror that here
    /// but also ensure each phase gets at least 1 day and ranges tile without overlap.
    /// Day range derived from CycleMath.cyclePhase() — single source of truth.
    public func dayRange(cycleLength: Int, bleedingDays: Int = 5) -> ClosedRange<Int> {
        let cl = max(1, cycleLength)
        var start: Int?
        var end: Int?
        for day in 1...cl {
            let phase = CycleMath.cyclePhase(cycleDay: day, cycleLength: cl, bleedingDays: bleedingDays)
            let matches = CyclePhase(rawValue: phase.rawValue) == self
            if matches {
                if start == nil { start = day }
                end = day
            }
        }
        guard let s = start, let e = end else { return cl...cl }
        return s...e
    }
}

// MARK: - Phase Guidance

extension CyclePhase {

    public var energyLevel: Int {   // 1-5
        switch self {
        case .menstrual: 1
        case .follicular: 3
        case .ovulatory: 5
        case .luteal: 2
        }
    }

    public var moodLevel: Int {     // 1-5
        switch self {
        case .menstrual: 2
        case .follicular: 4
        case .ovulatory: 5
        case .luteal: 3
        }
    }

    public var focusLevel: Int {    // 1-5
        switch self {
        case .menstrual: 2
        case .follicular: 4
        case .ovulatory: 4
        case .luteal: 5
        }
    }

    public var bestFor: [String] {
        switch self {
        case .menstrual: ["Journaling", "Light walks", "Setting intentions", "Deep conversations"]
        case .follicular: ["Starting projects", "Brainstorming", "Learning new skills", "Social plans"]
        case .ovulatory: ["Presentations", "Difficult conversations", "Dates", "Negotiating"]
        case .luteal: ["Editing work", "Organizing", "Honest self-assessment", "Finishing projects"]
        }
    }

    public var avoid: [String] {
        switch self {
        case .menstrual: ["Overcommitting", "Intense workouts", "Big decisions"]
        case .follicular: ["Routine tasks", "Playing it safe", "Ignoring new ideas"]
        case .ovulatory: ["Isolation", "Underestimating your impact", "People-pleasing"]
        case .luteal: ["Starting new things", "Ignoring your boundaries", "Suppressing emotions"]
        }
    }

    public var readings: [String] {
        switch self {
        case .menstrual: [
            "Your body is asking for stillness. The quieter you become, the more you hear.",
            "This is your reset. Old energy is leaving — let it. What remains is what matters.",
            "You're not lazy, you're recharging. The women who rest here are the ones who rise strongest.",
            "Your intuition is sharpest when your body is still. Listen to what surfaces today.",
            "Nothing grows without rest first. Honor the pause."
        ]
        case .follicular: [
            "Something in you is waking up. Follow the curiosity — it knows where to go.",
            "Your energy is climbing. Today favors the new — new ideas, new conversations, new risks.",
            "You're entering your most creative window. The ideas that come now are worth writing down.",
            "Your mind is sharp and your mood is lifting. Use this momentum before it peaks.",
            "Your body is building momentum. Plant the seeds now — you'll harvest them soon."
        ]
        case .ovulatory: [
            "Your magnetic energy is at its highest. People are drawn to you — use it wisely.",
            "This is your moment. Say the thing, make the ask, take the stage. Your confidence isn't an illusion.",
            "You're radiating. The boldest version of you is the truest version right now.",
            "Your communication is at its peak. The words you speak today carry extra weight.",
            "You're in your power. Don't shrink to make others comfortable — they'll adjust."
        ]
        case .luteal: [
            "Your inner editor is awake. The things that bother you now are showing you what needs to change.",
            "You see through everything right now. That sharp eye isn't negativity — it's clarity.",
            "This is your finishing phase. What you started two weeks ago? Complete it now.",
            "Your tolerance for nonsense drops here. That's not a flaw — it's a boundary forming.",
            "The discomfort you feel is transformation. You're turning raw experience into wisdom."
        ]
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
