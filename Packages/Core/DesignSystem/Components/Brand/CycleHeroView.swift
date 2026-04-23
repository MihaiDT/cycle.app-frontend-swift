import SwiftUI
import UIKit

// MARK: - Cycle Hero View

/// Unified hero with scroll-collapse: full gradient card with calendar + cycle info
/// morphs into a compact sticky header as user scrolls. Apple-style interpolation.
// MARK: - Overlay-awareness Environment
//
// Signals to the Home tab tree that something is slid over it
// (Calendar overlay, Cycle Insights overlay). Animated components
// read this to pause themselves — a 30Hz `TimelineView` or a
// `repeatForever` animation keeps driving the SwiftUI graph and
// the render thread even when fully hidden behind another view,
// which shows up as constant `ViewGraph.beginNextUpdate` work in
// Instruments and causes stutters in whatever overlay is on top.

private struct IsBehindOverlayKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

public extension EnvironmentValues {
    /// `true` when the current view is rendered underneath an active
    /// overlay (Calendar / Cycle Insights). Heavy ambient animations
    /// should check this and either unmount or stop their loops.
    var isBehindOverlay: Bool {
        get { self[IsBehindOverlayKey.self] }
        set { self[IsBehindOverlayKey.self] = newValue }
    }
}

public struct CycleHeroView: View {
    public let cycle: CycleContext
    @Binding public var selectedDate: Date?
    /// True while Home is reloading cycle data after a period edit
    public var isRefreshing: Bool
    /// True briefly after sync completes (shows checkmark confirmation)
    public var isSynced: Bool
    public var onEditPeriod: (() -> Void)?
    public var onLogPeriod: (() -> Void)?
    public var onCalendarTapped: (() -> Void)?
    public var hasNotification: Bool
    public var onNotificationTapped: (() -> Void)?
    /// 0 = fully expanded, 1 = fully collapsed
    public var collapseProgress: CGFloat
    /// Safe area inset from top (to extend behind status bar)
    public var safeAreaTop: CGFloat
    public var aiWellnessMessage: String?
    public var isLoadingWellnessMessage: Bool

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.isBehindOverlay) var isBehindOverlay

    let cal = Calendar.current

    // Layout constants
    let expandedHeight: CGFloat = 258
    let collapsedHeight: CGFloat = 64
    /// How much the asymmetric curve extends below the rect
    let curveDepth: CGFloat = 32

    /// Wave drop animation: 0 = normal position, 1 = shifted to top
    @State var waveDropOffset: CGFloat = 0

    public init(
        cycle: CycleContext,
        selectedDate: Binding<Date?>,
        isRefreshing: Bool = false,
        isSynced: Bool = false,
        onEditPeriod: (() -> Void)? = nil,
        onLogPeriod: (() -> Void)? = nil,
        onCalendarTapped: (() -> Void)? = nil,
        hasNotification: Bool = false,
        onNotificationTapped: (() -> Void)? = nil,
        collapseProgress: CGFloat = 0,
        safeAreaTop: CGFloat = 0,
        aiWellnessMessage: String? = nil,
        isLoadingWellnessMessage: Bool = false
    ) {
        self.cycle = cycle
        self._selectedDate = selectedDate
        self.isRefreshing = isRefreshing
        self.isSynced = isSynced
        self.onEditPeriod = onEditPeriod
        self.onLogPeriod = onLogPeriod
        self.onCalendarTapped = onCalendarTapped
        self.hasNotification = hasNotification
        self.onNotificationTapped = onNotificationTapped
        self.collapseProgress = collapseProgress
        self.safeAreaTop = safeAreaTop
        self.aiWellnessMessage = aiWellnessMessage
        self.isLoadingWellnessMessage = isLoadingWellnessMessage
    }

    // MARK: - Interpolation Helpers

    var progress: CGFloat { min(max(collapseProgress, 0), 1) }

    func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        a + (b - a) * progress
    }

    /// Total height tracks scroll 1:1 — the caller already applies an
    /// S-curve to scrollOffset, so adding another easing here would
    /// double-ease and make the collapse feel faster than the finger.
    var currentHeight: CGFloat {
        lerp(expandedHeight, collapsedHeight) + safeAreaTop
    }

    /// Wave intensity by phase — menstrual is most active, luteal is calm
    var phaseWaveIntensity: CGFloat {
        if isLateMode { return 0.15 } // Very subtle — waiting state
        switch displayPhase {
        case .menstrual: return 1.0     // Full wave — active, energetic
        case .ovulatory: return 0.75    // Lively
        case .follicular: return 0.45   // Gentle ripple
        case .luteal: return 0.2        // Nearly flat — calm, winding down
        case .late: return 0.15         // Very subtle — waiting state
        }
    }

    /// 0 = gentle wave, 1 = chaotic blob (active during sync)
    var waveBlobMorph: CGFloat {
        isRefreshing ? 0.5 : 0.15
    }

    /// Curve depth scales with collapse progress AND phase intensity.
    /// Subtle boost during sync so the wave is slightly more active.
    var currentCurveDepth: CGFloat {
        let base = lerp(curveDepth * phaseWaveIntensity, 0)
        let syncBoost = curveDepth * 1.2 * waveBlobMorph * (1 - progress)
        return base + syncBoost
    }

    // MARK: - Computed Display Properties

    static let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()

    var monthLabel: String {
        Self.monthFormatter.string(from: effectiveDate)
    }

    var periodCountdownText: String {
        if isPeriod && !isPredictedPeriod {
            return "Period · Day \(displayCycleDay)"
        }
        let days = daysUntilPeriod
        if days == 0 { return "Period expected today" }
        if days == 1 { return "Period expected tomorrow" }
        if days <= 3 { return "Period in \(days) days" }
        return "\(days) days until period"
    }

    var wellnessMessage: String {
        if isRefreshing { return "Updating..." }
        if cycle.isLate { return "Your period may start any day" }

        let days = daysUntilPeriod
        if days == 0 { return "Your period is expected today" }
        if days == 1 { return "Your period is coming tomorrow" }
        if days > 0 && days <= 3 { return "Your period is coming soon" }
        if days > 3 && days <= 14 { return "\(days) days until your period" }

        switch displayPhase {
        case .menstrual: return "Take it easy today"
        case .follicular: return "Your energy is rising"
        case .ovulatory: return "You're at your peak"
        case .luteal: return "Your body is winding down"
        case .late: return "Your period may start any day"
        }
    }

    var effectiveDate: Date {
        selectedDate ?? cal.startOfDay(for: Date())
    }

    var displayPhase: CyclePhase {
        cycle.resolvedPhase(for: effectiveDate)
    }

    var displayCycleDay: Int {
        // When late, show real cycle day (43), not wrapped (15)
        if cycle.isLate && cal.isDateInToday(effectiveDate) { return cycle.cycleDay }
        return cycle.cycleDayNumber(for: effectiveDate) ?? cycle.cycleDay
    }

    var periodDayNumber: Int? {
        cycle.periodBlockDay(for: effectiveDate)
    }

    var isPeriod: Bool {
        cycle.isPeriodDay(effectiveDate)
    }

    var isPredictedPeriod: Bool {
        cycle.isPredictedOnly(effectiveDate)
    }

    /// True when the effective date is a confirmed (non-predicted) period day
    var isConfirmedPeriodDay: Bool {
        isPeriod && !isPredictedPeriod
    }

    var isLatePrediction: Bool {
        cycle.isLatePrediction(effectiveDate)
    }

    var daysUntilPeriod: Int {
        cycle.daysUntilPeriod(from: effectiveDate)
    }

    /// True when viewing today and the period is late/missing
    var isLateForDate: Bool {
        guard isLateMode else { return false }
        return cal.isDateInToday(effectiveDate)
    }

    /// True when the cycle is in late mode (regardless of which day is selected).
    /// Uses isLate directly — the confirmed period at the START of the cycle
    /// doesn't mean the NEXT period arrived.
    var isLateMode: Bool {
        cycle.isLate
    }

    // MARK: - Display Text

    var phaseLabel: String {
        if isLatePrediction { return "Period Expected" }
        if isLateForDate { return "Period Late" }
        // Future predicted period → before isPeriod (which also matches predicted)
        if isPredictedPeriod { return displayPhase.displayName }
        if isPeriod { return "Period" }
        if displayPhase == .ovulatory && (cycle.fertileWindowActive || isFertileDay) { return "Fertile Window" }
        let today = cal.startOfDay(for: Date())
        let d = cal.startOfDay(for: effectiveDate)
        if d < today {
            return "Past \(displayPhase.displayName)"
        }
        return displayPhase.displayName
    }

    var dayText: String {
        if isLatePrediction { return "Not logged" }
        if isLateForDate {
            let days = cycle.effectiveDaysLate
            if days == 1 { return "1 day late" }
            return "\(days) days late"
        }
        if isPeriod {
            let day = periodDayNumber ?? displayCycleDay
            return "Day \(day)"
        }
        return "Day \(displayCycleDay)"
    }

    /// Whether the effective date falls in a fertile day (from calendar API data)
    var isFertileDay: Bool {
        cycle.fertileDays[cycle.dateKey(for: effectiveDate)] != nil
    }

    var subtitle: String {
        if isLatePrediction { return "Tap to log if period started" }
        if isLateForDate { return "Expected \(cycle.effectiveDaysLate) days ago" }

        // Future dates while in late mode — predictions are uncertain
        if isLateMode && cal.startOfDay(for: effectiveDate) > cal.startOfDay(for: Date()) {
            return "Will adjust after logging"
        }

        if isPeriod && isPredictedPeriod && (selectedDate == nil || cal.isDateInToday(effectiveDate)) { return "May start today" }
        if isPeriod { return "of your period" }

        // Fertile window: suppress when late — predictions are unreliable
        if !cycle.isLate {
            if cycle.fertileWindowActive || isFertileDay { return "You may be fertile" }
        }

        let days = daysUntilPeriod
        if days <= 0 { return "Period expected today" }
        if days == 1 { return "1 day until period" }
        if days <= 14 { return "\(days) days until period" }

        if !cycle.isLate, let fwStart = cycle.fertileWindowStart {
            let fwDays = cal.dateComponents([.day], from: cal.startOfDay(for: effectiveDate), to: cal.startOfDay(for: fwStart)).day ?? 0
            if fwDays > 0 && fwDays <= 10 {
                return fwDays == 1 ? "Fertile window in 1 day" : "Fertile window in \(fwDays) days"
            }
        }

        return phaseMood.text
    }

    /// Compact subtitle for collapsed state
    var compactSubtitle: String {
        if isLateForDate { return "\(cycle.effectiveDaysLate)d late" }
        if isLateMode && cal.startOfDay(for: effectiveDate) > cal.startOfDay(for: Date()) {
            return "Estimated"
        }
        if isPeriod { return subtitle }
        let days = daysUntilPeriod
        if days > 0 && days <= 14 { return "\(days)d to period" }
        return phaseLabel
    }

    // MARK: - Phase Mood (base set — AI-generated in future)

    /// Returns a mood phrase + SF Symbol for the current phase and cycle day.
    /// Deterministic based on cycle day so it stays stable for the day.
    var phaseMood: (text: String, icon: String) {
        let moods = Self.phaseMoods[displayPhase] ?? Self.phaseMoods[.follicular]!
        let index = (displayCycleDay - 1) % moods.count
        return moods[index]
    }

    static let phaseMoods: [CyclePhase: [(text: String, icon: String)]] = [
        .menstrual: [
            ("Recovery", "bed.double"),
            ("Low energy", "battery.25percent"),
            ("Rest day", "moon.zzz"),
            ("Restorative", "heart"),
            ("Gentle pace", "tortoise"),
        ],
        .follicular: [
            ("Rising energy", "arrow.up.right"),
            ("Building", "chart.line.uptrend.xyaxis"),
            ("Momentum", "wind"),
            ("Renewed", "leaf"),
            ("Focused", "scope"),
        ],
        .ovulatory: [
            ("Peak energy", "bolt"),
            ("High vitality", "sun.max"),
            ("At your best", "star"),
            ("Confident", "figure.stand"),
            ("Social", "person.2"),
        ],
        .luteal: [
            ("Winding down", "sunset"),
            ("Reflective", "cloud.sun"),
            ("Inner focus", "brain.head.profile"),
            ("Settling in", "house"),
            ("Quiet mode", "leaf"),
        ],
        .late: [
            ("Listening to your body", "ear"),
            ("Be patient", "clock"),
            ("Check in with yourself", "heart.text.square"),
            ("Take it easy", "leaf"),
            ("Stay aware", "eye"),
        ],
    ]

    var dateHeaderString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: effectiveDate)
    }

    // MARK: - Phase Colors (Warm cream base, phase-tinted accents)

    /// Warm cream gradient matching onboarding background, with subtle phase tint
    var heroGradientStart: Color {
        Color(hex: 0xFEFCF7) // Cream white — same as onboarding
    }

    var heroGradientEnd: Color {
        if isLateMode {
            return Color(red: 0.88, green: 0.87, blue: 0.85) // Warm gray cream
        }
        switch displayPhase {
        case .menstrual: return Color(red: 0.93, green: 0.82, blue: 0.79) // Warm rose cream
        case .follicular: return Color(red: 0.82, green: 0.91, blue: 0.87) // Sage cream
        case .ovulatory: return Color(red: 0.94, green: 0.89, blue: 0.78) // Golden cream
        case .luteal: return Color(red: 0.88, green: 0.85, blue: 0.93) // Lavender cream
        case .late: return Color(red: 0.88, green: 0.87, blue: 0.85) // Warm gray cream
        }
    }

    /// Phase accent for small UI elements (dots, borders, buttons)
    var phaseAccent: Color {
        if isLateMode {
            return Color(red: 0.55, green: 0.50, blue: 0.48) // Warm taupe
        }
        switch displayPhase {
        case .menstrual: return Color(red: 0.76, green: 0.42, blue: 0.45)
        case .follicular: return Color(red: 0.36, green: 0.65, blue: 0.55)
        case .ovulatory: return Color(red: 0.82, green: 0.62, blue: 0.30)
        case .luteal: return Color(red: 0.55, green: 0.45, blue: 0.72)
        case .late: return Color(red: 0.55, green: 0.50, blue: 0.48)
        }
    }

    var textOnHeroColor: Color {
        DesignColors.text
    }

    // MARK: - Body

    // MARK: - Crossfade

    /// Expanded opacity — fade out window 0.28 → 0.58.
    /// Overlaps with collapsed fade-in so the hero never hits a blank
    /// frame mid-collapse (previous 0.35 → 0.50 window left a visible
    /// "both invisible" gap right at progress 0.50).
    var expandedOpacity: Double {
        let t = Double((progress - 0.28) / 0.30).clamped(to: 0...1)
        // Smooth fade-out (1 - easeInOut(t))
        return 1 - (t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2)
    }

    /// Collapsed opacity — fade in window 0.42 → 0.72.
    /// Overlaps the tail of the expanded fade-out so both layers
    /// breathe together for ~8 progress-points, giving a soft dissolve
    /// rather than a hard crossfade.
    var collapsedOpacity: Double {
        let t = Double((progress - 0.42) / 0.30).clamped(to: 0...1)
        return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    /// Wave phase derived from wall clock — constant speed, never resets
    func wavePhase(from date: Date) -> CGFloat {
        CGFloat(date.timeIntervalSinceReferenceDate * .pi * 2.0 / 12.0)
    }

    public var body: some View {
        ZStack(alignment: .top) {
            // Content
            VStack(spacing: 0) {
                Color.clear.frame(height: safeAreaTop)

                ZStack(alignment: .top) {
                    expandedContent
                        .opacity(expandedOpacity)
                        .allowsHitTesting(progress < 0.5)

                    collapsedContent
                        .frame(maxHeight: .infinity, alignment: .center)
                        .opacity(collapsedOpacity)
                        .allowsHitTesting(progress >= 0.5)
                }
            }
        }
        .frame(height: currentHeight)
        .background {
            JourneyAnimatedBackground()
        }
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            DesignColors.text.opacity(0.22),
                            DesignColors.accentWarm.opacity(0.38),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
        .shadow(color: DesignColors.text.opacity(0.18), radius: 20, x: 0, y: 8)
        .shadow(color: DesignColors.text.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    // MARK: - Expanded Content (full hero)

    /// Staggered element opacity — bottom elements disappear first.
    /// Eased with easeInOut so each element's fade feels like a settle,
    /// not a linear ramp (previously each tile snapped in/out uniformly
    /// which made the whole stack feel mechanical).
    func staggeredOpacity(fadeEnd: CGFloat) -> Double {
        let fadeStart = max(fadeEnd - 0.2, 0)
        if progress <= fadeStart { return 1 }
        if progress >= fadeEnd { return 0 }
        let t = Double((progress - fadeStart) / (fadeEnd - fadeStart))
        let eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
        return 1 - eased
}
}
