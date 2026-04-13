import SwiftUI
import UIKit

// MARK: - Cycle Hero View

/// Unified hero with scroll-collapse: full gradient card with calendar + cycle info
/// morphs into a compact sticky header as user scrolls. Apple-style interpolation.
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

    private let cal = Calendar.current

    // Layout constants
    private let expandedHeight: CGFloat = 290
    private let collapsedHeight: CGFloat = 64
    /// How much the asymmetric curve extends below the rect
    private let curveDepth: CGFloat = 32

    /// Wave drop animation: 0 = normal position, 1 = shifted to top
    @State private var waveDropOffset: CGFloat = 0

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

    private var progress: CGFloat { min(max(collapseProgress, 0), 1) }

    private func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        a + (b - a) * progress
    }

    /// Total height including safe area top extension
    private var currentHeight: CGFloat {
        lerp(expandedHeight, collapsedHeight) + safeAreaTop
    }

    /// Wave intensity by phase — menstrual is most active, luteal is calm
    private var phaseWaveIntensity: CGFloat {
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
    private var waveBlobMorph: CGFloat {
        isRefreshing ? 0.5 : 0.15
    }

    /// Curve depth scales with collapse progress AND phase intensity.
    /// Subtle boost during sync so the wave is slightly more active.
    private var currentCurveDepth: CGFloat {
        let base = lerp(curveDepth * phaseWaveIntensity, 0)
        let syncBoost = curveDepth * 1.2 * waveBlobMorph * (1 - progress)
        return base + syncBoost
    }

    // MARK: - Computed Display Properties

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()

    private var monthLabel: String {
        Self.monthFormatter.string(from: effectiveDate)
    }

    // `glassCircle` was removed — all top-bar icon buttons now use `GlowIconButtonStyle`.

    private var periodCountdownText: String {
        if isPeriod && !isPredictedPeriod {
            return "Period · Day \(displayCycleDay)"
        }
        let days = daysUntilPeriod
        if days == 0 { return "Period expected today" }
        if days == 1 { return "Period expected tomorrow" }
        if days <= 3 { return "Period in \(days) days" }
        return "\(days) days until period"
    }

    private var wellnessMessage: String {
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

    private var effectiveDate: Date {
        selectedDate ?? cal.startOfDay(for: Date())
    }

    private var displayPhase: CyclePhase {
        cycle.resolvedPhase(for: effectiveDate)
    }

    private var displayCycleDay: Int {
        // When late, show real cycle day (43), not wrapped (15)
        if cycle.isLate && cal.isDateInToday(effectiveDate) { return cycle.cycleDay }
        return cycle.cycleDayNumber(for: effectiveDate) ?? cycle.cycleDay
    }

    private var periodDayNumber: Int? {
        cycle.periodBlockDay(for: effectiveDate)
    }

    private var isPeriod: Bool {
        cycle.isPeriodDay(effectiveDate)
    }

    private var isPredictedPeriod: Bool {
        cycle.isPredictedOnly(effectiveDate)
    }

    /// True when the effective date is a confirmed (non-predicted) period day
    private var isConfirmedPeriodDay: Bool {
        isPeriod && !isPredictedPeriod
    }

    private var isLatePrediction: Bool {
        cycle.isLatePrediction(effectiveDate)
    }

    private var daysUntilPeriod: Int {
        cycle.daysUntilPeriod(from: effectiveDate)
    }

    /// True when viewing today and the period is late/missing
    private var isLateForDate: Bool {
        guard isLateMode else { return false }
        return cal.isDateInToday(effectiveDate)
    }

    /// True when the cycle is in late mode (regardless of which day is selected).
    /// Uses isLate directly — the confirmed period at the START of the cycle
    /// doesn't mean the NEXT period arrived.
    private var isLateMode: Bool {
        cycle.isLate
    }

    // MARK: - Display Text

    private var phaseLabel: String {
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

    private var dayText: String {
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
    private var isFertileDay: Bool {
        cycle.fertileDays[cycle.dateKey(for: effectiveDate)] != nil
    }

    private var subtitle: String {
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
    private var compactSubtitle: String {
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
    private var phaseMood: (text: String, icon: String) {
        let moods = Self.phaseMoods[displayPhase] ?? Self.phaseMoods[.follicular]!
        let index = (displayCycleDay - 1) % moods.count
        return moods[index]
    }

    private static let phaseMoods: [CyclePhase: [(text: String, icon: String)]] = [
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

    private var dateHeaderString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: effectiveDate)
    }

    // MARK: - Phase Colors (Warm cream base, phase-tinted accents)

    /// Warm cream gradient matching onboarding background, with subtle phase tint
    private var heroGradientStart: Color {
        Color(hex: 0xFEFCF7) // Cream white — same as onboarding
    }

    private var heroGradientEnd: Color {
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
    private var phaseAccent: Color {
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

    private var textOnHeroColor: Color {
        DesignColors.text
    }

    // MARK: - Body

    // MARK: - Crossfade

    /// Expanded master opacity: fully visible until 0.35, gone by 0.50
    private var expandedOpacity: Double {
        Double(1 - max(0, progress - 0.35) / 0.15).clamped(to: 0...1)
    }

    /// Collapsed opacity: invisible until 0.50, fully visible by 0.65
    private var collapsedOpacity: Double {
        Double((progress - 0.50) / 0.15).clamped(to: 0...1)
    }

    /// Wave phase derived from wall clock — constant speed, never resets
    private func wavePhase(from date: Date) -> CGFloat {
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
        .clipped()
        .modifier(GlassCardModifier())
    }

    // MARK: - Expanded Content (full hero)

    /// Staggered element opacity: bottom elements disappear first during collapse.
    /// `fadeEnd` = progress at which element is fully gone. Earlier = disappears sooner.
    private func staggeredOpacity(fadeEnd: CGFloat) -> Double {
        let fadeStart = max(fadeEnd - 0.2, 0)
        if progress <= fadeStart { return 1 }
        if progress >= fadeEnd { return 0 }
        return Double(1 - (progress - fadeStart) / (fadeEnd - fadeStart))
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 0) {
            // Top bar: profile + day/phase info + calendar button
            HStack(spacing: 0) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onNotificationTapped?()
                } label: {
                    Image(systemName: hasNotification ? "bell.badge.fill" : "bell.fill")
                        .symbolRenderingMode(hasNotification ? .palette : .monochrome)
                        .foregroundStyle(
                            DesignColors.background,
                            DesignColors.accentWarm
                        )
                }
                .buttonStyle(GlowIconButtonStyle())
                .accessibilityLabel(hasNotification ? "Notifications, new" : "Notifications")

                Spacer()

                // Month name centered in top bar
                Text(monthLabel)
                    .font(.custom("Raleway-Black", size: 17, relativeTo: .body))
                    .tracking(-0.3)
                    .foregroundColor(textOnHeroColor)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onCalendarTapped?()
                } label: {
                    if isRefreshing {
                        ProgressView()
                            .tint(DesignColors.background)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "calendar")
                    }
                }
                .buttonStyle(GlowIconButtonStyle())
                .animation(.easeInOut(duration: 0.25), value: isRefreshing)
                .accessibilityLabel("Calendar")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .opacity(staggeredOpacity(fadeEnd: 0.60))

            // Week calendar
            MiniCycleCalendar(
                cycle: cycle,
                selectedDate: $selectedDate,
                embedded: true
            )
            .padding(.top, 4)
            .opacity(staggeredOpacity(fadeEnd: 0.55))
            .allowsHitTesting(progress < 0.3)

            // Warm wellness message under calendar
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignColors.structure.opacity(0.3))
                    .frame(width: 200, height: 16)
                    .opacity(isLoadingWellnessMessage ? 1 : 0)

                Text(aiWellnessMessage ?? wellnessMessage)
                    .font(.custom("Raleway-MediumItalic", size: 17, relativeTo: .body))
                    .foregroundColor(textOnHeroColor.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(height: 44)
                    .opacity(isLoadingWellnessMessage ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .animation(.easeInOut(duration: 0.3), value: aiWellnessMessage)
            .opacity(staggeredOpacity(fadeEnd: 0.50))

            // Cycle status — matches collapsed header
            Text(collapsedHeadline)
                .font(.custom("Raleway-Medium", size: 15, relativeTo: .callout))
                .foregroundColor(textOnHeroColor.opacity(0.5))
                .padding(.top, 6)
                .opacity(staggeredOpacity(fadeEnd: 0.45))

            Spacer(minLength: 12)

            // Action buttons — compact row
            HStack(spacing: 10) {
                if let onLogPeriod, !isConfirmedPeriodDay,
                   cycle.isLate || isPredictedPeriod || isLatePrediction || isLateForDate || displayPhase == .menstrual {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onLogPeriod()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Log period")
                                .font(.custom("Raleway-Black", size: 15, relativeTo: .callout))
                                .tracking(-0.2)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .overlay {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.2), Color.clear],
                                                startPoint: .top,
                                                endPoint: .center
                                            )
                                        )
                                }
                                .shadow(color: DesignColors.accentWarm.opacity(0.4), radius: 12, x: 0, y: 4)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshing)
                    .opacity(isRefreshing ? 0.5 : 1)
                }

                if let onEditPeriod {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onEditPeriod()
                    } label: {
                        Text("My cycle")
                            .font(.custom("Raleway-Black", size: 15, relativeTo: .callout))
                            .tracking(-0.2)
                            .foregroundColor(textOnHeroColor)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background {
                                ZStack {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.95), Color.white.opacity(0.7)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                    // Top shine
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.9), Color.clear],
                                                startPoint: .top,
                                                endPoint: .center
                                            )
                                        )
                                        .padding(2)
                                    // Border
                                    Capsule()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.8), DesignColors.accentWarm.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                }
                            }
                            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                            .shadow(color: DesignColors.accentWarm.opacity(0.12), radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 14)
            .opacity(staggeredOpacity(fadeEnd: 0.40))
        }
    }

    // MARK: - Collapsed Content (compact header)

    @ViewBuilder
    private var collapsedContent: some View {
        HStack(spacing: 0) {
            // Status summary
            VStack(alignment: .leading, spacing: 3) {
                Text(collapsedHeadline)
                    .font(.custom("Raleway-Black", size: 17, relativeTo: .body))
                    .tracking(-0.3)
                    .foregroundColor(textOnHeroColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            // Calendar button — dark cocoa GlowIconButtonStyle
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onCalendarTapped?()
            } label: {
                if isRefreshing {
                    ProgressView()
                        .tint(DesignColors.background)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "calendar")
                }
            }
            .buttonStyle(GlowIconButtonStyle())
            .animation(.easeInOut(duration: 0.25), value: isRefreshing)
            .accessibilityLabel("Calendar")
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Collapsed Text

    private var collapsedHeadline: String {
        if isRefreshing { return "Updating..." }
        if cycle.isLate {
            let late = cycle.effectiveDaysLate
            if late <= 1 { return "Period expected" }
            return "Period expected \(late) days ago"
        }

        if isPeriod && !isPredictedPeriod {
            let bleed = cycle.bleedingDays
            let periodDay = max(1, displayCycleDay)
            return "Period · Day \(periodDay) of \(bleed)"
        }

        if cycle.fertileWindowActive || isFertileDay {
            return "Fertile window"
        }

        if displayPhase == .ovulatory {
            return "Peak day"
        }

        let days = daysUntilPeriod
        if days == 1 { return "Period in 1 day" }
        if days > 0 && days <= 3 { return "Period in \(days) days" }
        if days > 3 && days <= 14 { return "\(days) days until period" }

        return phaseLabel
    }

    private var collapsedDetail: String {
        ""
    }

}

// MARK: - Animated Wave Slash Shape

/// Rectangle with an animated sine-wave bottom edge. The wave drifts
/// horizontally over time via `wavePhase`, with `slashHeight` controlling
/// the wave amplitude. When `blobMorph` > 0, extra noise frequencies kick
/// in and the amplitude boosts — the gentle wave transforms into an organic
/// chaotic blob, then morphs back when the sync completes.
// MARK: - Shimmer Effect

private struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: max(0, phase - 0.15)),
                        .init(color: .white.opacity(0.4), location: max(0, phase)),
                        .init(color: .clear, location: min(1, phase + 0.15)),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

// MARK: - Wave Shape

private struct WaveSlashShape: Shape {
    var slashHeight: CGFloat
    var wavePhase: CGFloat
    /// 0 = gentle wave, 1 = chaotic blob morph
    var blobMorph: CGFloat = 0

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(slashHeight, wavePhase), blobMorph) }
        set {
            slashHeight = newValue.first.first
            wavePhase = newValue.first.second
            blobMorph = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let baseY = rect.height - slashHeight

        path.move(to: .zero)
        path.addLine(to: CGPoint(x: w, y: 0))

        // Breathing pulse during blob morph — slow swell
        let breathe = 1.0 + sin(wavePhase * 0.5) * 0.15 * blobMorph

        // Wave bottom edge — sampled every 2pt for smoothness
        let steps = max(Int(w / 2), 1)
        for i in stride(from: steps, through: 0, by: -1) {
            let x = w * CGFloat(i) / CGFloat(steps)
            let normalizedX = x / w

            // Base waves (always active) — gentle, low frequency
            let wave1 = sin(normalizedX * .pi * 2.0 + wavePhase) * 0.6
            let wave2 = sin(normalizedX * .pi * 3.5 + wavePhase * 0.7) * 0.4

            // Blob: smooth low-frequency undulations, large amplitude
            let blob1 = sin(normalizedX * .pi * 1.2 + wavePhase * 1.4) * 0.7 * blobMorph
            let blob2 = cos(normalizedX * .pi * 2.3 - wavePhase * 0.9) * 0.5 * blobMorph

            let combined = (wave1 + wave2 + blob1 + blob2) * breathe
            let y = baseY + slashHeight * combined
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Double Clamping

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview("Menstrual Day 2") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        CycleHeroView(
            cycle: CycleContext(
                cycleDay: 2,
                cycleLength: 28,
                bleedingDays: 5,
                cycleStartDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                currentPhase: .menstrual,
                nextPeriodIn: nil,
                fertileWindowActive: false,
                periodDays: [],
                predictedDays: []
            ),
            selectedDate: .constant(nil),
            onEditPeriod: {},
            onCalendarTapped: {}
        )
        .padding(.horizontal, 16)
    }
}

#Preview("Collapsed") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        VStack {
            CycleHeroView(
                cycle: CycleContext(
                    cycleDay: 14,
                    cycleLength: 28,
                    bleedingDays: 5,
                    cycleStartDate: Calendar.current.date(byAdding: .day, value: -13, to: Date())!,
                    currentPhase: .ovulatory,
                    nextPeriodIn: 15,
                    fertileWindowActive: true,
                    periodDays: [],
                    predictedDays: []
                ),
                selectedDate: .constant(nil),
                onEditPeriod: {},
                onCalendarTapped: {},
                collapseProgress: 1.0
            )
            .padding(.horizontal, 16)
            Spacer()
        }
    }
}
