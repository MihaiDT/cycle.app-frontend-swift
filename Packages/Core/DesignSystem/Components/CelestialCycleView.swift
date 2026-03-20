import SwiftUI

// MARK: - Celestial Cycle View

/// Premium orbital cycle visualization with full accessibility support.
/// Interactive: drag along the orbit to explore days, haptic feedback at phase crossings,
/// tap phases for detail tooltips. Canvas + TimelineView at 30fps with multi-layer particle system.
/// Supports VoiceOver adjustable action and reduced-motion preferences.
public struct CelestialCycleView: View {
    public let cycle: CycleContext
    public var collapseProgress: CGFloat
    /// Ring drag exploring day (1-based, current cycle only). Nil = show current day.
    @Binding public var exploringDay: Int?
    /// Calendar-selected date (any date in range). Nil = no calendar selection.
    @Binding public var calendarDate: Date?
    public var onLogPeriod: ((Date?) -> Void)?

    @State private var isDragging = false
    @State private var lastHapticPhase: CyclePhase?
    @State private var lastDragAngle: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        cycle: CycleContext,
        collapseProgress: CGFloat = 0,
        exploringDay: Binding<Int?>,
        calendarDate: Binding<Date?> = .constant(nil),
        onLogPeriod: ((Date?) -> Void)? = nil
    ) {
        self.cycle = cycle
        self.collapseProgress = collapseProgress
        self._exploringDay = exploringDay
        self._calendarDate = calendarDate
        self.onLogPeriod = onLogPeriod
    }

    private var currentPhase: CyclePhase {
        cycle.currentPhase
    }

    // MARK: - Display Properties
    //
    // ALL cycle day math delegated to CycleContext — no local arithmetic.
    // Priority: isDragging → calendarDate → exploringDay (post-drag) → default (today)

    /// The effective date for display — calendar selection or today.
    private var effectiveDate: Date {
        calendarDate ?? Calendar.current.startOfDay(for: Date())
    }

    /// Cycle day for the effective date (delegates to CycleContext).
    /// For today with no selection: returns server cycle day (can be > cycleLength for overdue).
    /// For other dates: uses CycleContext which handles predicted blocks correctly.
    private var effectiveCycleDay: Int {
        if calendarDate == nil { return cycle.cycleDay }
        return cycle.cycleDayNumber(for: effectiveDate) ?? cycle.cycleDay
    }

    /// Cycle day (1-based) for center text — can be > cycleLength for overdue today.
    private var displayDay: Int {
        exploringDay ?? effectiveCycleDay
    }

    /// Phase for center text display — server-aware, suppresses math-based menstrual for future cycles.
    private var displayPhase: CyclePhase {
        if exploringDay == nil {
            return cycle.phase(for: effectiveDate) ?? cycle.phase(forCycleDay: min(effectiveCycleDay, cycle.cycleLength))
        }
        return cycle.phase(forCycleDay: exploringDay!)
    }

    private var daysUntilPeriodForDisplay: Int {
        if exploringDay == nil {
            return cycle.daysUntilPeriod(from: effectiveDate)
        }
        return cycle.daysUntilPeriod(fromCycleDay: exploringDay!)
    }

    private var isOverdue: Bool {
        exploringDay == nil && calendarDate == nil && cycle.cycleDay > cycle.cycleLength
    }

    private var overdueDays: Int {
        cycle.cycleDay - cycle.cycleLength
    }

    /// Whether the calendar is pointing at a future cycle date
    private var isEstimatedDate: Bool {
        guard let date = calendarDate else { return false }
        guard let info = cycle.cycleDayInfo(for: date) else { return false }
        return info.offset > 0
    }

    // MARK: - Center Text (Flo/Stardust-style contextual message)
    //
    // Display matrix (title / subtitle):
    //   Menstrual day (current or predicted)    → "Period"   / "Day N"
    //   Overdue (no exploring, day > length)    → "Period"   / "N days late"
    //   Period expected today                   → "Period"   / "expected today" or "today"
    //   Period tomorrow                         → "Period"   / "starts tomorrow" or "may start\ntomorrow"
    //   Period within 7 days                    → "Period in"/ "N days"
    //   Fertile/ovulatory (current cycle)       → "Fertile"  / "Window"
    //   Normal day (current cycle)              → phase name / "Day N"
    //   Non-period day in future cycle          → "Period in"/ "N days"

    private var periodContextTitle: String {
        // 1. On a period day — works for both current cycle and next-cycle predicted
        if displayPhase == .menstrual { return "Period" }

        // 2. Overdue: past expected date, period hasn't come
        if isOverdue { return "Period" }

        // 3. Days-until-period flow
        let days = daysUntilPeriodForDisplay
        let isEstimated = exploringDay != nil || isEstimatedDate
        if days <= 0 { return isEstimated ? "Period expected" : "Period" }
        if days == 1 { return "Period" }
        if days <= 7 { return "Period in" }

        // 4. Fertile window (current cycle only)
        if displayPhase == .ovulatory && !isEstimatedDate { return "Fertile" }

        // 5. Future cycle non-period days or normal current-cycle day
        return isEstimatedDate ? "Period in" : displayPhase.displayName
    }

    private var periodContextSubtitle: String {
        // 1. On a period day — show cycle day (matches ring position)
        if displayPhase == .menstrual {
            return "Day \(min(displayDay, cycle.cycleLength))"
        }

        // 2. Overdue
        if isOverdue {
            return overdueDays == 1 ? "1 day late" : "\(overdueDays) days late"
        }

        // 3. Days-until-period flow
        let days = daysUntilPeriodForDisplay
        let isEstimated = exploringDay != nil || isEstimatedDate
        if days <= 0 { return isEstimated ? "today" : "expected today" }
        if days == 1 { return isEstimated ? "starts tomorrow" : "may start\ntomorrow" }
        if days <= 7 { return "\(days) days" }

        // 4. Fertile window (current cycle only)
        if displayPhase == .ovulatory && !isEstimatedDate { return "Window" }

        // 5. Future cycle non-period days
        if isEstimatedDate { return "\(days) days" }

        // 6. Normal current-cycle day
        return "Day \(displayDay)"
    }

    public var body: some View {
        mainContent
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityValue("Day \(displayDay) of \(cycle.cycleLength)")
            .accessibilityHint("Swipe up or down to explore cycle days")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    let next = min(cycle.cycleLength, (exploringDay ?? cycle.cycleDay) + 1)
                    exploringDay = next
                    triggerHaptic(.light)
                case .decrement:
                    let prev = max(1, (exploringDay ?? cycle.cycleDay) - 1)
                    exploringDay = prev
                    triggerHaptic(.light)
                @unknown default:
                    break
                }
            }
            .onChange(of: collapseProgress) { _, newValue in
                if newValue > 0.1 && (exploringDay != nil || calendarDate != nil) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        exploringDay = nil
                        calendarDate = nil
                        isDragging = false
                    }
                }
            }
    }

    // MARK: - Main Content

    private var hideProgress: Double {
        min(1, max(0, collapseProgress * 2.5))
    }

    // Day number stays visible longer
    private var numberHideProgress: Double {
        min(1, max(0, (collapseProgress - 0.6) / 0.3))
    }

    /// Ring position — capped at cycleLength so overdue shows nearly-full, not wrapped to day 1.
    private var ringDay: Int {
        if let exploringDay { return exploringDay }
        return min(effectiveCycleDay, cycle.cycleLength)
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            ZStack {
                ambientGlow
                    .opacity(1 - hideProgress)
                    .animation(.easeInOut(duration: 0.6), value: displayPhase)
                    .allowsHitTesting(false)

                CelestialOrbitCanvas(
                    displayDay: ringDay,
                    cycleLength: cycle.cycleLength,
                    bleedingDays: cycle.effectiveBleedingDays,
                    phase: currentPhase,
                    displayPhase: displayPhase,
                    isDragging: isDragging,
                    reduceMotion: reduceMotion,
                    collapseProgress: collapseProgress
                )
                .frame(width: 340, height: 340)
                .allowsHitTesting(false)
                .overlay {
                    if !reduceMotion {
                        CosmicParticleEmitter(
                            displayDay: ringDay,
                            cycleLength: cycle.cycleLength
                        )
                        .frame(width: 340, height: 340)
                        .allowsHitTesting(false)
                        .opacity(1 - hideProgress)
                    }
                }

                VStack(spacing: 12) {
                    centerContent
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: displayDay)

                    if let onLogPeriod, collapseProgress < 0.1 {
                        let isOnPeriodDay = displayPhase == .menstrual
                        Button {
                            onLogPeriod(calendarDate)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isOnPeriodDay ? "pencil" : "drop.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(isOnPeriodDay ? "Edit Period" : "Log Period")
                                    .font(.custom("Raleway-SemiBold", size: 13))
                            }
                            .foregroundColor(CyclePhase.menstrual.orbitColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        Capsule().strokeBorder(CyclePhase.menstrual.orbitColor.opacity(0.3), lineWidth: 0.5)
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }

                gestureOverlay
                    .allowsHitTesting(collapseProgress < 0.1)
            }

            contextPills
                .opacity(1 - hideProgress)
                .padding(.top, 16)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: displayDay)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .animation(.easeInOut(duration: 0.4), value: displayPhase)
    }

    private var accessibilityDescription: String {
        let phaseName = displayPhase.displayName
        let exploring = exploringDay != nil
        var desc = "\(phaseName) phase, day \(displayDay) of \(cycle.cycleLength) day cycle"
        if exploring { desc += ", exploring" }
        if let daysUntil = cycle.nextPeriodIn, daysUntil > 0 {
            desc += ", \(daysUntil) days until next period"
        }
        if cycle.fertileWindowActive { desc += ", fertile window active" }
        return desc
    }

    // MARK: - Ambient Glow

    private var ambientGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        displayPhase.glowColor.opacity(isDragging ? 0.12 : 0.07),
                        displayPhase.glowColor.opacity(0.02),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 60,
                    endRadius: 160
                )
            )
            .frame(width: 380, height: 380)
            .blur(radius: 20)
    }

    // MARK: - Gesture Overlay

    private var gestureOverlay: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 20

            Color.clear
                // Ring content shape: only the orbit zone captures touches.
                // Center area passes through to the ScrollView for scrolling.
                .contentShape(Circle().subtracting(Circle().inset(by: 80)))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let dx = value.location.x - center.x
                            let dy = value.location.y - center.y
                            let distFromCenter = sqrt(dx * dx + dy * dy)

                            // Only respond to touches near the orbit, not center
                            guard distFromCenter > radius * 0.6 && distFromCenter < radius * 1.45 else {
                                if isDragging {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        isDragging = false
                                        lastDragAngle = nil
                                    }
                                }
                                return
                            }

                            let angle = atan2(dy, dx)

                            if !isDragging {
                                // First touch — snap to nearest day, clear calendar selection
                                isDragging = true
                                calendarDate = nil
                                lastDragAngle = angle
                                let day = dayForAngle(angle)
                                exploringDay = day
                                lastHapticPhase = cycle.phase(forCycleDay: day)
                                triggerHaptic(.light)
                                return
                            }

                            // Incremental tracking: compute angular delta from last position
                            guard let prevAngle = lastDragAngle else {
                                lastDragAngle = angle
                                return
                            }

                            // Calculate shortest angular difference (handles wrap-around)
                            var delta = angle - prevAngle
                            if delta > .pi { delta -= 2 * .pi }
                            if delta < -.pi { delta += 2 * .pi }

                            // Convert angular delta to fractional days
                            let dayAngle = (2 * .pi) / Double(max(cycle.cycleLength, 1))
                            let dayDelta = delta / dayAngle

                            // Only advance when accumulated movement crosses a day boundary
                            let currentDay = exploringDay ?? cycle.cycleDay
                            let daysMoved = Int(dayDelta.rounded())

                            if daysMoved != 0 {
                                // Only allow moving one day at a time for smoothness
                                let clampedMove = daysMoved > 0 ? 1 : -1
                                let newDay = currentDay + clampedMove

                                // Clamp to valid range — no wrapping
                                guard newDay >= 1 && newDay <= cycle.cycleLength else {
                                    lastDragAngle = angle
                                    return
                                }

                                exploringDay = newDay
                                // Reset lastDragAngle to current position minus the leftover
                                lastDragAngle = prevAngle + Double(clampedMove) * dayAngle

                                // Haptic tick on every day change
                                triggerHaptic(.light)

                                let newPhase = cycle.phase(forCycleDay: newDay)
                                if newPhase != lastHapticPhase {
                                    lastHapticPhase = newPhase
                                    triggerHaptic(.medium)
                                }
                            }
                        }
                        .onEnded { _ in
                            lastDragAngle = nil
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                isDragging = false
                                if exploringDay == cycle.cycleDay {
                                    exploringDay = nil
                                }
                            }
                            triggerHaptic(.light)
                        }
                )

        }
        .frame(width: 340, height: 340)
    }

    private func dismissSelection() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            exploringDay = nil
            calendarDate = nil
            isDragging = false
        }
        triggerHaptic(.light)
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    // MARK: - Phase Header

    private var phaseHeader: some View {
        HStack(spacing: 10) {
            // Phase color indicator dot
            Circle()
                .fill(displayPhase.orbitColor)
                .frame(width: 8, height: 8)
                .shadow(color: displayPhase.glowColor.opacity(0.5), radius: 4)

            Text(displayPhase.emoji)
                .font(.system(size: 20))

            Text(displayPhase.displayName)
                .font(.custom("Raleway-Bold", size: 18))
                .foregroundColor(DesignColors.text)
                .contentTransition(.numericText())

            Spacer()

            Text("Day \(displayDay)")
                .font(.custom("Raleway-SemiBold", size: 13))
                .foregroundColor(displayPhase.glowColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(displayPhase.glowColor.opacity(0.12))
                        .overlay {
                            Capsule()
                                .strokeBorder(displayPhase.glowColor.opacity(0.2), lineWidth: 0.5)
                        }
                }
                .contentTransition(.numericText())

            if isDragging {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(displayPhase.glowColor)
                    .transition(.scale.combined(with: .opacity))
            } else if exploringDay != nil {
                Image(systemName: "scope")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(displayPhase.glowColor.opacity(0.7))
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Center Content

    @ViewBuilder
    private var centerContent: some View {
        let collapse = hideProgress
        // Compensate for parent scaleEffect shrinking the view
        let counterScale: CGFloat = 1.0 + collapse * 1.2

        VStack(spacing: 2) {
            if isDragging {
                // Dragging on orbit: show Day number
                VStack(spacing: 0) {
                    Text("Day")
                        .font(.custom("Raleway-Medium", size: 14))
                        .foregroundColor(DesignColors.textSecondary)

                    Text("\(displayDay)")
                        .font(.custom("Raleway-Bold", size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    displayPhase.orbitColor.opacity(0.85),
                                    displayPhase.glowColor.opacity(0.75)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Text("\(displayDay)")
                                .font(.custom("Raleway-Bold", size: 48))
                                .foregroundStyle(.ultraThinMaterial)
                                .blendMode(.overlay)
                        }
                        .contentTransition(.numericText(countsDown: displayDay < cycle.cycleDay))
                        .scaleEffect(1.08)
                }
                .scaleEffect(counterScale)

                Text(displayPhase.displayName)
                    .font(.custom("Raleway-SemiBold", size: 13))
                    .foregroundColor(displayPhase.orbitColor.opacity(0.8))
                    .contentTransition(.numericText())
            } else {
                // Flo-style contextual message
                Text(periodContextTitle)
                    .font(.custom("Raleway-Bold", size: 22))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                displayPhase.orbitColor.opacity(0.9),
                                displayPhase.glowColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())
                    .opacity(1 - collapse * 0.5)

                Text(periodContextSubtitle)
                    .font(.custom("Raleway-Bold", size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                displayPhase.orbitColor.opacity(0.85),
                                displayPhase.glowColor.opacity(0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Text(periodContextSubtitle)
                            .font(.custom("Raleway-Bold", size: 28))
                            .foregroundStyle(.ultraThinMaterial)
                            .blendMode(.overlay)
                    }
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())
                    .scaleEffect(counterScale)

                // Cycle day pill + phase
                HStack(spacing: 6) {
                    Text("Day \(displayDay)")
                        .font(.custom("Raleway-SemiBold", size: 11))
                        .foregroundColor(displayPhase.orbitColor.opacity(0.8))

                    Circle()
                        .fill(displayPhase.orbitColor.opacity(0.4))
                        .frame(width: 3, height: 3)

                    Text(displayPhase.displayName)
                        .font(.custom("Raleway-Medium", size: 11))
                        .foregroundColor(DesignColors.textSecondary.opacity(0.7))
                }
                .opacity(1 - collapse)
                .frame(height: (1 - collapse) * 16, alignment: .center)
                .clipped()

                // Future/past cycle indicator
                if isEstimatedDate {
                    Text("Estimated")
                        .font(.custom("Raleway-Medium", size: 10))
                        .foregroundColor(DesignColors.textSecondary.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .fill(DesignColors.textSecondary.opacity(0.08))
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .opacity(1 - collapse)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDragging)
    }

    // MARK: - Context Pills

    private var isExploring: Bool {
        isDragging || exploringDay != nil || calendarDate != nil
    }

    private var contextPills: some View {
        HStack(spacing: 10) {
            if isExploring {
                if !isDragging {
                    Button {
                        dismissSelection()
                    } label: {
                        contextPill(
                            icon: "arrow.uturn.backward",
                            text: "Back to today",
                            color: DesignColors.textSecondary
                        )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            } else {
                if let daysUntil = cycle.nextPeriodIn {
                    contextPill(
                        icon: "calendar",
                        text: daysUntil == 0 ? "Period today" : "\(daysUntil)d until period",
                        color: CyclePhase.menstrual.glowColor
                    )
                }

                if cycle.fertileWindowActive {
                    contextPill(
                        icon: "sparkles",
                        text: "Fertile window",
                        color: CyclePhase.ovulatory.glowColor
                    )
                }

                if !cycle.fertileWindowActive && cycle.nextPeriodIn == nil {
                    contextPill(
                        icon: "heart.fill",
                        text: currentPhase.insight,
                        color: currentPhase.glowColor
                    )
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExploring)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isDragging)
    }

    private func contextPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
            }
            Text(text)
                .font(.custom("Raleway-Medium", size: 12))
                .lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(color.opacity(0.08))
                .overlay {
                    Capsule()
                        .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
                }
        }
    }

    // MARK: - Helpers

    private func dayForAngle(_ angle: Double) -> Int {
        let normalized = (angle + .pi / 2).truncatingRemainder(dividingBy: 2 * .pi)
        let positive = normalized < 0 ? normalized + 2 * .pi : normalized
        let fraction = positive / (2 * .pi)
        return max(1, min(cycle.cycleLength, Int(fraction * Double(cycle.cycleLength)) + 1))
    }
}

// MARK: - Celestial Orbit Canvas

/// Canvas that draws the cycle orbit with phase arcs, glass effects, and orb marker.
private struct CelestialOrbitCanvas: View {
    /// The resolved cycle day to display (1-based, already capped at cycleLength by caller).
    let displayDay: Int
    let cycleLength: Int
    let bleedingDays: Int
    let phase: CyclePhase
    /// The resolved phase for the current display day (from CycleContext, server-aware)
    let displayPhase: CyclePhase
    let isDragging: Bool
    let reduceMotion: Bool
    var collapseProgress: CGFloat = 0

    @State private var fillAngle: Double = -.pi / 2

    /// Wrapped display day (1-based) for ring position.
    private var wrappedDay: Int {
        guard cycleLength > 0 else { return 1 }
        return ((displayDay - 1) % cycleLength) + 1
    }

    /// Target angle = exact proportional position of the current (wrapped) day on the circle.
    private var targetAngle: Double {
        exactAngle(forDay: wrappedDay, of: cycleLength)
    }

    /// Combined key so the fill animation re-triggers when day or cycle length changes
    private var fillTaskKey: Int {
        return displayDay &* 31 &+ cycleLength
    }

    var body: some View {
        let currentFill = fillAngle
        let collapse = collapseProgress

        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius: Double = min(size.width, size.height) / 2 - 20

            // Base track only visible when collapsing
            if collapse > 0.05 {
                context.opacity = Double(min(1, collapse * 3))
                drawBaseTrack(context: &context, center: center, radius: radius)
                context.opacity = 1
            }
            drawFilledTrack(context: &context, center: center, radius: radius, fillAngle: currentFill)
            drawPhaseArcs(context: &context, center: center, radius: radius, fillAngle: currentFill)
            drawOrbMarker(context: &context, center: center, radius: radius, orbAngle: currentFill)
        }
        .task(id: fillTaskKey) {
            let target = targetAngle
            let start = fillAngle
            let duration: Double = isDragging ? 0.15 : reduceMotion ? 0.0 : 0.5

            guard duration > 0, abs(target - start) > 0.001 else {
                fillAngle = target
                return
            }

            let began = Date.now
            while !Task.isCancelled {
                let elapsed = Date.now.timeIntervalSince(began)
                let t = min(1.0, elapsed / duration)
                let eased = 1.0 - pow(1.0 - t, 3)
                fillAngle = start + (target - start) * eased
                if t >= 1.0 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    // MARK: - Base Track (full circle border)

    private func drawBaseTrack(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: Double
    ) {
        let arcWidth: CGFloat = 14
        var trackPath = Path()
        trackPath.addArc(
            center: center, radius: radius,
            startAngle: .degrees(0), endAngle: .degrees(360),
            clockwise: false
        )
        context.stroke(
            trackPath,
            with: .color(Color(red: 0xDE / 255.0, green: 0xCB / 255.0, blue: 0xC1 / 255.0).opacity(0.18)),
            style: StrokeStyle(lineWidth: arcWidth, lineCap: .round)
        )
    }

    // MARK: - Liquid Glass Track

    private func drawFilledTrack(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        fillAngle: Double
    ) {
        let startAngle = -Double.pi / 2
        let arcWidth: CGFloat = 14

        guard fillAngle > startAngle + 0.01 else { return }

        // --- Layer 1: Frosted glass body ---
        var glassPath = Path()
        glassPath.addArc(center: center, radius: radius, startAngle: .radians(startAngle), endAngle: .radians(fillAngle), clockwise: false)
        context.stroke(
            glassPath,
            with: .color(Color(red: 0xDE / 255.0, green: 0xCB / 255.0, blue: 0xC1 / 255.0).opacity(0.10)),
            style: StrokeStyle(lineWidth: arcWidth, lineCap: .round)
        )

        // --- Layer 2: Inner rim highlight ---
        var innerPath = Path()
        innerPath.addArc(center: center, radius: radius - Double(arcWidth / 2) + 0.8, startAngle: .radians(startAngle), endAngle: .radians(fillAngle), clockwise: false)
        context.stroke(
            innerPath,
            with: .color(Color.white.opacity(0.14)),
            lineWidth: 0.5
        )

        // --- Layer 3: Outer rim depth ---
        var outerPath = Path()
        outerPath.addArc(center: center, radius: radius + Double(arcWidth / 2) - 0.8, startAngle: .radians(startAngle), endAngle: .radians(fillAngle), clockwise: false)
        context.stroke(
            outerPath,
            with: .color(Color.black.opacity(0.04)),
            lineWidth: 0.5
        )
    }

    // MARK: - Phase Arcs (glass effect)

    private func drawPhaseArcs(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        fillAngle: Double
    ) {
        let startAngle = -Double.pi / 2
        let fullCircle = fillAngle >= startAngle + 2 * .pi - 0.05
        let arcWidth: CGFloat = 14

        for phaseItem in CyclePhase.allCases {
            let range = phaseItem.dayRange(cycleLength: cycleLength, bleedingDays: bleedingDays)
            let phaseStart = Double(range.lowerBound - 1) / Double(max(cycleLength, 1)) * 2 * .pi + startAngle
            let phaseEnd = Double(range.upperBound) / Double(max(cycleLength, 1)) * 2 * .pi + startAngle

            guard fillAngle > phaseStart else { continue }
            let clampedEnd = min(phaseEnd, fillAngle)

            // --- Layer 1: Phase color ---
            var bodyPath = Path()
            bodyPath.addArc(center: center, radius: radius, startAngle: .radians(phaseStart), endAngle: .radians(clampedEnd), clockwise: false)
            context.stroke(
                bodyPath,
                with: .color(phaseItem.orbitColor.opacity(0.55)),
                style: StrokeStyle(lineWidth: arcWidth, lineCap: .butt)
            )

            // --- Layer 2: Inner highlight ---
            var innerPath = Path()
            innerPath.addArc(center: center, radius: radius - Double(arcWidth / 2) + 1, startAngle: .radians(phaseStart), endAngle: .radians(clampedEnd), clockwise: false)
            context.stroke(
                innerPath,
                with: .color(Color.white.opacity(0.25)),
                lineWidth: 1.0
            )

            // --- Layer 3: Specular shine ---
            var shinePath = Path()
            shinePath.addArc(center: center, radius: radius - Double(arcWidth * 0.15), startAngle: .radians(phaseStart), endAngle: .radians(clampedEnd), clockwise: false)
            context.stroke(
                shinePath,
                with: .color(Color.white.opacity(0.12)),
                style: StrokeStyle(lineWidth: arcWidth * 0.35, lineCap: .butt)
            )

            // --- Layer 4: Outer depth ---
            var outerPath = Path()
            outerPath.addArc(center: center, radius: radius + Double(arcWidth / 2) - 1, startAngle: .radians(phaseStart), endAngle: .radians(clampedEnd), clockwise: false)
            context.stroke(
                outerPath,
                with: .color(phaseItem.orbitColor.opacity(0.15)),
                lineWidth: 0.8
            )
        }

        // Smooth fade at the start
        if !fullCircle {
            let fadeAngle = Double.pi * 0.1
            let clampedFade = min(fadeAngle, fillAngle - startAngle)
            guard clampedFade > 0.01 else { return }

            let fadeSteps = 24
            for i in 0..<fadeSteps {
                let t = Double(i) / Double(fadeSteps)
                let tNext = Double(i + 1) / Double(fadeSteps)

                let inv = 1.0 - t
                let eraseAlpha = inv * inv * inv * 0.9

                var seg = Path()
                seg.addArc(
                    center: center, radius: radius,
                    startAngle: .radians(startAngle + t * clampedFade),
                    endAngle: .radians(startAngle + tNext * clampedFade),
                    clockwise: false
                )
                context.stroke(
                    seg,
                    with: .color(Color(uiColor: .systemBackground).opacity(eraseAlpha)),
                    style: StrokeStyle(lineWidth: 12, lineCap: .butt)
                )
            }
        }
    }

    // MARK: - Orb Marker

    private func drawOrbMarker(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        orbAngle: Double
    ) {
        let orbPhase = displayPhase

        let orbCenter = CGPoint(
            x: center.x + cos(orbAngle) * radius,
            y: center.y + sin(orbAngle) * radius
        )

        // --- Soft outer bloom ---
        let bloomSize = 38.0
        let bloomRect = CGRect(
            x: orbCenter.x - bloomSize / 2,
            y: orbCenter.y - bloomSize / 2,
            width: bloomSize,
            height: bloomSize
        )
        context.fill(
            Path(ellipseIn: bloomRect),
            with: .radialGradient(
                Gradient(colors: [
                    orbPhase.glowColor.opacity(0.25),
                    orbPhase.glowColor.opacity(0.06),
                    orbPhase.glowColor.opacity(0),
                ]),
                center: orbCenter,
                startRadius: 0,
                endRadius: bloomSize / 2
            )
        )

        // --- Cross light rays ---
        let rayLen = 14.0
        let rayWidth: CGFloat = 1.2
        for i in 0..<4 {
            let angle = Double(i) * .pi / 4
            let dx = cos(angle) * rayLen / 2
            let dy = sin(angle) * rayLen / 2
            var rayPath = Path()
            rayPath.move(to: CGPoint(x: orbCenter.x - dx, y: orbCenter.y - dy))
            rayPath.addLine(to: CGPoint(x: orbCenter.x + dx, y: orbCenter.y + dy))
            context.stroke(
                rayPath,
                with: .color(.white.opacity(i % 2 == 0 ? 0.5 : 0.25)),
                lineWidth: rayWidth
            )
        }

        // --- Main gemstone ---
        let gemSize = 12.0
        var gemCtx = context
        gemCtx.addFilter(.shadow(color: orbPhase.glowColor.opacity(0.6), radius: 6))

        let gemRect = CGRect(x: -gemSize / 2, y: -gemSize / 2, width: gemSize, height: gemSize)
        let gemPath = Path(roundedRect: gemRect, cornerRadius: 3.0)
        gemCtx.translateBy(x: orbCenter.x, y: orbCenter.y)
        gemCtx.rotate(by: .radians(.pi / 4))

        gemCtx.fill(
            gemPath,
            with: .linearGradient(
                Gradient(colors: [.white, orbPhase.orbitColor.opacity(0.7)]),
                startPoint: CGPoint(x: -gemSize * 0.3, y: -gemSize * 0.5),
                endPoint: CGPoint(x: gemSize * 0.3, y: gemSize * 0.5)
            )
        )
        gemCtx.stroke(gemPath, with: .color(.white.opacity(0.7)), lineWidth: 0.8)
    }

    // MARK: - Helpers

    private func exactAngle(forDay day: Int, of total: Int) -> Double {
        // Center of the current day's arc segment: Day 1 → 0.5/28 (small visible arc),
        // Day 28 → 27.5/28 (nearly full, gap before top). Never reaches 100%.
        let fraction = (Double(day) - 0.5) / Double(max(total, 1))
        return fraction * 2 * .pi - .pi / 2
    }

    private func angleForDay(_ day: Int) -> Double {
        let fraction = Double(day - 1) / Double(max(cycleLength, 1))
        return fraction * 2 * .pi - .pi / 2
    }

    private func dayForAngle(_ angle: Double) -> Int {
        let normalized = (angle + .pi / 2).truncatingRemainder(dividingBy: 2 * .pi)
        let positive = normalized < 0 ? normalized + 2 * .pi : normalized
        let fraction = positive / (2 * .pi)
        return max(1, min(cycleLength, Int(fraction * Double(cycleLength)) + 1))
    }

    private func phaseForDay(_ day: Int) -> CyclePhase {
        for p in CyclePhase.allCases {
            if p.dayRange(cycleLength: cycleLength, bleedingDays: bleedingDays).contains(day) { return p }
        }
        return .luteal
    }
}

// MARK: - Cosmic Particle Emitter (CAEmitterLayer)

/// Hardware-accelerated particle emitter that renders cosmic dust along the unfilled
/// arc of the cycle. Uses multiple CAEmitterCells per phase for a realistic nebula effect.
private struct CosmicParticleEmitter: UIViewRepresentable {
    let displayDay: Int
    let cycleLength: Int

    func makeUIView(context: Context) -> CosmicParticleView {
        let view = CosmicParticleView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.displayDay = displayDay
        view.cycleLen = cycleLength
        return view
    }

    func updateUIView(_ uiView: CosmicParticleView, context: Context) {
        uiView.displayDay = displayDay
        uiView.cycleLen = cycleLength
        if Thread.isMainThread {
            uiView.rebuildEmitters()
        } else {
            DispatchQueue.main.async {
                uiView.rebuildEmitters()
            }
        }
    }
}

private final class CosmicParticleView: UIView {
    // Emitter layers — recreated when needed to avoid pre-warm issues
    private var fieldLayer: CAEmitterLayer?
    private var vortexLayer: CAEmitterLayer?
    var displayDay: Int = 1
    var cycleLen: Int = 28

    override func layoutSubviews() {
        super.layoutSubviews()
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [self] in rebuildEmitters() }
            return
        }
        rebuildEmitters()
    }

    private func makeFieldLayer() -> CAEmitterLayer {
        let l = CAEmitterLayer()
        l.renderMode = .additive
        return l
    }

    private func makeVortexLayer() -> CAEmitterLayer {
        let l = CAEmitterLayer()
        l.renderMode = .additive
        return l
    }

    func rebuildEmitters() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 20
        guard radius > 10 else { return }

        let startAngle = -Double.pi / 2
        let fillFraction = Double(displayDay) / Double(max(cycleLen, 1))
        let fillAngle = fillFraction * 2 * .pi + startAngle
        let fullCircle = 2.0 * Double.pi
        let unfilledSpan = startAngle + fullCircle - fillAngle

        guard unfilledSpan > 0.02 else {
            // Remove layers entirely — clean slate for next time
            fieldLayer?.removeFromSuperlayer()
            vortexLayer?.removeFromSuperlayer()
            fieldLayer = nil
            vortexLayer = nil
            return
        }

        // Create fresh layers if needed (first time or after being at day 28)
        if fieldLayer == nil {
            let fl = makeFieldLayer()
            let vl = makeVortexLayer()
            layer.addSublayer(fl)
            layer.addSublayer(vl)
            fieldLayer = fl
            vortexLayer = vl
        }

        guard let fieldLayer, let vortexLayer else { return }

        // Scale birthRate to arc size
        let arcFraction = unfilledSpan / fullCircle
        let spanFactor = Float(max(0.15, arcFraction))

        // --- Phase colors sampled along the unfilled arc ---
        let midAngle = fillAngle + unfilledSpan / 2
        let midDay = dayForAngle(midAngle, cycleLength: cycleLen)
        let midPhase = phaseForDay(midDay, cycleLength: cycleLen)

        let orbDay = dayForAngle(fillAngle, cycleLength: cycleLen)
        let orbPhase = phaseForDay(orbDay, cycleLength: cycleLen)

        // =========================================================
        // MARK: Field emitter — dense continuous particle cloud
        // =========================================================
        fieldLayer.emitterPosition = center
        fieldLayer.emitterSize = CGSize(width: radius * 2, height: radius * 2)
        fieldLayer.emitterShape = .circle
        // .outline — born exactly on the circumference, organic scatter via velocity
        fieldLayer.emitterMode = .outline
        fieldLayer.birthRate = spanFactor

        // App palette UIColors for particles
        let roseTaupe = UIColor(red: 0xC8 / 255.0, green: 0xAD / 255.0, blue: 0xA7 / 255.0, alpha: 1)  // #C8ADA7
        let dustyRose = UIColor(red: 0xD6 / 255.0, green: 0xA5 / 255.0, blue: 0x9A / 255.0, alpha: 1)  // #D6A59A
        let softBlush = UIColor(red: 0xEB / 255.0, green: 0xCF / 255.0, blue: 0xC3 / 255.0, alpha: 1)  // #EBCFC3
        let warmSandstone = UIColor(red: 0xDE / 255.0, green: 0xCB / 255.0, blue: 0xC1 / 255.0, alpha: 1)  // #DECBC1

        // Dust — warm rose taupe motes
        let dust = CAEmitterCell()
        dust.birthRate = 40
        dust.lifetime = 5.5
        dust.lifetimeRange = 3.0
        dust.velocity = 4
        dust.velocityRange = 10
        dust.emissionRange = .pi * 2
        dust.scale = 0.018
        dust.scaleRange = 0.012
        dust.scaleSpeed = -0.001
        dust.alphaSpeed = -0.04
        dust.alphaRange = 0.2
        dust.spin = .pi * 0.06
        dust.spinRange = .pi * 0.25
        dust.color = roseTaupe.withAlphaComponent(0.3).cgColor
        dust.contents = Self.circleImage?.cgImage

        // Glow — soft blush halos
        let glow = CAEmitterCell()
        glow.birthRate = 12
        glow.lifetime = 6.5
        glow.lifetimeRange = 3.0
        glow.velocity = 3
        glow.velocityRange = 7
        glow.emissionRange = .pi * 2
        glow.scale = 0.035
        glow.scaleRange = 0.025
        glow.scaleSpeed = -0.001
        glow.alphaSpeed = -0.02
        glow.alphaRange = 0.1
        glow.color = softBlush.withAlphaComponent(0.12).cgColor
        glow.contents = Self.softGlowImage?.cgImage

        // Sparkle — dusty rose glints
        let sparkle = CAEmitterCell()
        sparkle.birthRate = 14
        sparkle.lifetime = 2.5
        sparkle.lifetimeRange = 1.2
        sparkle.velocity = 2
        sparkle.velocityRange = 4
        sparkle.emissionRange = .pi * 2
        sparkle.scale = 0.006
        sparkle.scaleRange = 0.004
        sparkle.alphaSpeed = -0.15
        sparkle.color = dustyRose.withAlphaComponent(0.4).cgColor
        sparkle.contents = Self.circleImage?.cgImage

        // Shimmer — warm sandstone orbs
        let shimmer = CAEmitterCell()
        shimmer.birthRate = 5
        shimmer.lifetime = 4.0
        shimmer.lifetimeRange = 2.0
        shimmer.velocity = 1.5
        shimmer.velocityRange = 3
        shimmer.emissionRange = .pi * 2
        shimmer.scale = 0.025
        shimmer.scaleRange = 0.015
        shimmer.scaleSpeed = -0.002
        shimmer.alphaSpeed = -0.03
        shimmer.alphaRange = 0.08
        shimmer.color = warmSandstone.withAlphaComponent(0.18).cgColor
        shimmer.contents = Self.softGlowImage?.cgImage

        fieldLayer.emitterCells = [dust, glow, sparkle, shimmer]

        // Rendered mask with fade zones on BOTH ends of the unfilled arc
        // So particles feather smoothly into the filled track on both sides
        let maskSize = bounds.size
        guard maskSize.width > 0, maskSize.height > 0 else { return }

        let renderer = UIGraphicsImageRenderer(size: maskSize)
        let maskImage = renderer.image { imgCtx in
            let gc = imgCtx.cgContext
            let lineW: CGFloat = 50
            let fadeAngle = min(Double.pi * 0.12, unfilledSpan * 0.3)  // ~22°, or 30% of arc if small
            let fadeSteps = 12

            // Fade-in zone near the orb (start of unfilled)
            for i in 0..<fadeSteps {
                let t = Double(i) / Double(fadeSteps)
                let tNext = Double(i + 1) / Double(fadeSteps)
                let alpha = CGFloat(t * t)  // ease-in quadratic
                let seg = UIBezierPath(
                    arcCenter: center,
                    radius: radius,
                    startAngle: fillAngle + t * fadeAngle,
                    endAngle: fillAngle + tNext * fadeAngle,
                    clockwise: true
                )
                gc.setStrokeColor(UIColor(white: 1, alpha: alpha).cgColor)
                gc.setLineWidth(lineW)
                gc.setLineCap(.butt)
                gc.addPath(seg.cgPath)
                gc.strokePath()
            }

            // Full-alpha middle zone
            let endAngle = startAngle + fullCircle
            let fullStart = fillAngle + fadeAngle
            let fullEnd = endAngle - fadeAngle
            if fullEnd > fullStart {
                let full = UIBezierPath(
                    arcCenter: center,
                    radius: radius,
                    startAngle: fullStart,
                    endAngle: fullEnd,
                    clockwise: true
                )
                gc.setStrokeColor(UIColor.white.cgColor)
                gc.setLineWidth(lineW)
                gc.setLineCap(.butt)
                gc.addPath(full.cgPath)
                gc.strokePath()
            }

            // Fade-out zone near the start of the filled arc (end of unfilled)
            for i in 0..<fadeSteps {
                let t = Double(i) / Double(fadeSteps)
                let tNext = Double(i + 1) / Double(fadeSteps)
                let alpha = CGFloat((1 - tNext) * (1 - tNext))  // ease-out → fades to 0
                let seg = UIBezierPath(
                    arcCenter: center,
                    radius: radius,
                    startAngle: endAngle - fadeAngle + t * fadeAngle,
                    endAngle: endAngle - fadeAngle + tNext * fadeAngle,
                    clockwise: true
                )
                gc.setStrokeColor(UIColor(white: 1, alpha: alpha).cgColor)
                gc.setLineWidth(lineW)
                gc.setLineCap(.butt)
                gc.addPath(seg.cgPath)
                gc.strokePath()
            }
        }

        let maskLayer = CALayer()
        maskLayer.frame = bounds
        maskLayer.contents = maskImage.cgImage
        fieldLayer.mask = maskLayer

        // =========================================================
        // MARK: Vortex emitter — absorption effect at orb position
        // =========================================================
        // Placed just ahead of the orb on the unfilled side.
        // Particles move inward toward the orb, shrink, and fade — looks like absorption.
        // Vortex spawns slightly ahead of orb on the unfilled side
        let vortexAngle = fillAngle + 0.08
        let orbX = center.x + cos(vortexAngle) * radius
        let orbY = center.y + sin(vortexAngle) * radius
        vortexLayer.emitterPosition = CGPoint(x: orbX, y: orbY)
        vortexLayer.emitterSize = CGSize(width: 44, height: 44)
        vortexLayer.emitterShape = .circle
        vortexLayer.emitterMode = .surface
        vortexLayer.birthRate = spanFactor

        // Tangent direction along the orbit toward the orb (clockwise absorption)
        let towardOrbAngle = fillAngle - .pi / 2  // tangent pointing toward fill direction
        let inwardAngle = atan2(center.y - orbY, center.x - orbX)
        // Blend between inward (toward center) and tangent (toward orb) for spiral absorption
        let absorbAngle = (inwardAngle + towardOrbAngle) / 2

        // Vortex app palette colors
        let vRoseTaupe = UIColor(red: 0xC8 / 255.0, green: 0xAD / 255.0, blue: 0xA7 / 255.0, alpha: 1)
        let vDustyRose = UIColor(red: 0xD6 / 255.0, green: 0xA5 / 255.0, blue: 0x9A / 255.0, alpha: 1)
        let vSoftBlush = UIColor(red: 0xEB / 255.0, green: 0xCF / 255.0, blue: 0xC3 / 255.0, alpha: 1)

        // Absorption dust — rose taupe shards spiraling toward orb
        let aDust = CAEmitterCell()
        aDust.birthRate = 22
        aDust.lifetime = 1.0
        aDust.lifetimeRange = 0.4
        aDust.velocity = 12
        aDust.velocityRange = 6
        aDust.emissionLongitude = CGFloat(absorbAngle)
        aDust.emissionRange = .pi * 0.6
        aDust.scale = 0.015
        aDust.scaleRange = 0.008
        aDust.scaleSpeed = -0.015
        aDust.alphaSpeed = -0.6
        aDust.spin = .pi * 0.4
        aDust.spinRange = .pi * 0.6
        aDust.color = vRoseTaupe.withAlphaComponent(0.35).cgColor
        aDust.contents = Self.circleImage?.cgImage

        // Absorption glow — soft blush converging halo
        let aGlow = CAEmitterCell()
        aGlow.birthRate = 8
        aGlow.lifetime = 0.7
        aGlow.lifetimeRange = 0.25
        aGlow.velocity = 8
        aGlow.velocityRange = 4
        aGlow.emissionLongitude = CGFloat(absorbAngle)
        aGlow.emissionRange = .pi * 0.5
        aGlow.scale = 0.022
        aGlow.scaleRange = 0.012
        aGlow.scaleSpeed = -0.025
        aGlow.alphaSpeed = -0.9
        aGlow.color = vSoftBlush.withAlphaComponent(0.18).cgColor
        aGlow.contents = Self.softGlowImage?.cgImage

        // Absorption sparkle — dusty rose glints converging
        let aSparkle = CAEmitterCell()
        aSparkle.birthRate = 8
        aSparkle.lifetime = 0.5
        aSparkle.lifetimeRange = 0.2
        aSparkle.velocity = 10
        aSparkle.velocityRange = 5
        aSparkle.emissionLongitude = CGFloat(absorbAngle)
        aSparkle.emissionRange = .pi * 0.4
        aSparkle.scale = 0.005
        aSparkle.scaleRange = 0.003
        aSparkle.scaleSpeed = -0.008
        aSparkle.alphaSpeed = -1.2
        aSparkle.color = vDustyRose.withAlphaComponent(0.4).cgColor
        aSparkle.contents = Self.circleImage?.cgImage

        vortexLayer.emitterCells = [aDust, aGlow, aSparkle]
    }

    // MARK: - Particle Images

    private static let circleImage: UIImage? = {
        let size: CGFloat = 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fillEllipse(in: rect)
        }
    }()

    private static let softGlowImage: UIImage? = {
        let size: CGFloat = 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let center = CGPoint(x: size / 2, y: size / 2)
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])
            {
                ctx.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: size / 2,
                    options: []
                )
            }
        }
    }()

    // MARK: - Helpers

    private func dayForAngle(_ angle: Double, cycleLength: Int) -> Int {
        let normalized = (angle + .pi / 2).truncatingRemainder(dividingBy: 2 * .pi)
        let positive = normalized < 0 ? normalized + 2 * .pi : normalized
        let fraction = positive / (2 * .pi)
        return max(1, min(cycleLength, Int(fraction * Double(cycleLength)) + 1))
    }

    private func phaseForDay(_ day: Int, cycleLength: Int) -> CyclePhase {
        for p in CyclePhase.allCases {
            if p.dayRange(cycleLength: cycleLength).contains(day) { return p }
        }
        return .luteal
    }
}

// MARK: - CyclePhase UIColor helpers

extension CyclePhase {
    fileprivate var uiColor: UIColor {
        switch self {
        case .menstrual: UIColor(red: 0.79, green: 0.25, blue: 0.38, alpha: 1)  // Deep Berry #C94060
        case .follicular: UIColor(red: 0.36, green: 0.72, blue: 0.65, alpha: 1)  // Teal #5BB8A6
        case .ovulatory: UIColor(red: 0.91, green: 0.66, blue: 0.22, alpha: 1)  // Amber Gold #E8A838
        case .luteal: UIColor(red: 0.55, green: 0.49, blue: 0.78, alpha: 1)  // Lavender #8B7EC8
        }
    }

    fileprivate var uiGlowColor: UIColor {
        switch self {
        case .menstrual: UIColor(red: 0.66, green: 0.19, blue: 0.31, alpha: 1)  // Deep Berry glow
        case .follicular: UIColor(red: 0.24, green: 0.60, blue: 0.53, alpha: 1)  // Teal glow
        case .ovulatory: UIColor(red: 0.80, green: 0.55, blue: 0.13, alpha: 1)  // Amber glow
        case .luteal: UIColor(red: 0.43, green: 0.38, blue: 0.69, alpha: 1)  // Lavender glow
        }
    }
}

// MARK: - CyclePhase Color Extensions

extension CyclePhase {
    var orbitColor: Color {
        switch self {
        case .menstrual: Color(red: 0.79, green: 0.25, blue: 0.38)  // Deep Berry
        case .follicular: Color(red: 0.36, green: 0.72, blue: 0.65)  // Teal
        case .ovulatory: Color(red: 0.91, green: 0.66, blue: 0.22)  // Amber Gold
        case .luteal: Color(red: 0.55, green: 0.49, blue: 0.78)  // Lavender
        }
    }

    var glowColor: Color {
        switch self {
        case .menstrual: Color(red: 0.66, green: 0.19, blue: 0.31)  // Deep Berry glow
        case .follicular: Color(red: 0.24, green: 0.60, blue: 0.53)  // Teal glow
        case .ovulatory: Color(red: 0.80, green: 0.55, blue: 0.13)  // Amber glow
        case .luteal: Color(red: 0.43, green: 0.38, blue: 0.69)  // Lavender glow
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .menstrual: [Color(red: 0.79, green: 0.25, blue: 0.38), Color(red: 0.66, green: 0.19, blue: 0.31)]
        case .follicular: [Color(red: 0.36, green: 0.72, blue: 0.65), Color(red: 0.24, green: 0.60, blue: 0.53)]
        case .ovulatory: [Color(red: 0.91, green: 0.66, blue: 0.22), Color(red: 0.80, green: 0.55, blue: 0.13)]
        case .luteal: [Color(red: 0.55, green: 0.49, blue: 0.78), Color(red: 0.43, green: 0.38, blue: 0.69)]
        }
    }
}

// MARK: - Celestial Mini Bar

/// Compact sticky bar shown when the full celestial circle scrolls off screen.
/// Displays a mini orbit ring with day number, phase info, and contextual detail.
public struct CelestialMiniBar: View {
    public let cycleDay: Int
    public let cycleLength: Int
    public let phase: String
    public let nextPeriodIn: Int?
    public let fertileWindowActive: Bool

    public init(
        cycleDay: Int,
        cycleLength: Int,
        phase: String,
        nextPeriodIn: Int?,
        fertileWindowActive: Bool
    ) {
        self.cycleDay = cycleDay
        self.cycleLength = cycleLength
        self.phase = phase
        self.nextPeriodIn = nextPeriodIn
        self.fertileWindowActive = fertileWindowActive
    }

    private var currentPhase: CyclePhase {
        CyclePhase(rawValue: phase) ?? .follicular
    }

    private var fillFraction: Double {
        Double(cycleDay) / Double(max(cycleLength, 1))
    }

    private var orbAngle: Double {
        fillFraction * 2 * .pi - .pi / 2
    }

    public var body: some View {
        HStack(spacing: 14) {
            miniOrbit

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(currentPhase.orbitColor)
                        .frame(width: 6, height: 6)

                    Text("Day \(cycleDay)")
                        .font(.custom("Raleway-Bold", size: 15))
                        .foregroundColor(DesignColors.text)

                    Text("·")
                        .foregroundColor(DesignColors.textSecondary)

                    Text(currentPhase.displayName)
                        .font(.custom("Raleway-Medium", size: 15))
                        .foregroundColor(currentPhase.orbitColor)
                }

                if let daysUntil = nextPeriodIn, daysUntil > 0 {
                    Text("\(daysUntil)d until period")
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundColor(DesignColors.textSecondary)
                } else if fertileWindowActive {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                        Text("Fertile window")
                            .font(.custom("Raleway-Regular", size: 12))
                    }
                    .foregroundColor(CyclePhase.ovulatory.glowColor)
                } else {
                    Text(currentPhase.insight)
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundColor(DesignColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    currentPhase.orbitColor.opacity(0.3),
                                    Color.white.opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        }
    }

    // MARK: - Mini Orbit

    private var miniOrbit: some View {
        ZStack {
            Circle()
                .stroke(DesignColors.textSecondary.opacity(0.12), lineWidth: 2.5)

            Circle()
                .trim(from: 0, to: fillFraction)
                .stroke(
                    currentPhase.orbitColor.opacity(0.6),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(currentPhase.orbitColor)
                .frame(width: 5, height: 5)
                .shadow(color: currentPhase.glowColor.opacity(0.7), radius: 3)
                .offset(
                    x: cos(orbAngle) * 17,
                    y: sin(orbAngle) * 17
                )

            Text("\(cycleDay)")
                .font(.custom("Raleway-Bold", size: 13))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            currentPhase.orbitColor.opacity(0.85),
                            currentPhase.glowColor.opacity(0.7),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .frame(width: 40, height: 40)
    }
}

// MARK: - Previews

private func previewCycle(_ day: Int, _ phase: CyclePhase, _ nextPeriod: Int?, _ fertile: Bool) -> CycleContext {
    CycleContext(
        cycleDay: day, cycleLength: 28, bleedingDays: 5,
        cycleStartDate: Calendar.current.date(byAdding: .day, value: -(day - 1), to: Date())!,
        currentPhase: phase, nextPeriodIn: nextPeriod, fertileWindowActive: fertile,
        periodDays: [], predictedDays: []
    )
}

#Preview("Follicular - Day 8") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        CelestialCycleView(cycle: previewCycle(8, .follicular, 21, false), exploringDay: .constant(nil))
            .padding()
    }
}

#Preview("Ovulatory - Day 14") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        CelestialCycleView(cycle: previewCycle(14, .ovulatory, 14, true), exploringDay: .constant(nil))
            .padding()
    }
}

#Preview("Menstrual - Day 2") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        CelestialCycleView(cycle: previewCycle(2, .menstrual, nil, false), exploringDay: .constant(nil))
            .padding()
    }
}
