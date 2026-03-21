import SwiftUI

// MARK: - Celestial Cycle View

/// Premium orbital cycle visualization.
///
/// ALL displayed values derive from server data via CycleContext:
/// - Period day number: `CycleContext.periodBlockDay(for:)` (position in server period block)
/// - Phase: `CycleContext.phase(for:)` (menstrual only if date is in server `periodDays`)
/// - Days until period: `CycleContext.daysUntilPeriod(from:)` (searches server calendar)
/// - Cycle day: `CycleContext.cycleDayNumber(for:)` (modular math from `cycleStartDate`)
///
/// `cycle.cycleDay` (raw server value) is never used for display — it can be wrong
/// when `cycleStartDate` is in the future after confirming a period.
public struct CelestialCycleView: View {
    public let cycle: CycleContext
    public var collapseProgress: CGFloat
    @Binding public var exploringDay: Int?
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

    // MARK: - Server-Derived Display Properties

    /// Today's cycle day — computed from cycleStartDate, never from server's clamped cycleDay.
    private var todayCycleDay: Int {
        cycle.cycleDayNumber(for: Calendar.current.startOfDay(for: Date())) ?? 1
    }

    /// The date the user is looking at — calendar selection or today.
    private var effectiveDate: Date {
        calendarDate ?? Calendar.current.startOfDay(for: Date())
    }

    /// Cycle day for the effective date.
    private var effectiveCycleDay: Int {
        cycle.cycleDayNumber(for: effectiveDate) ?? todayCycleDay
    }

    /// The day number shown in center text. Priority: drag > calendar > today.
    private var displayDay: Int {
        exploringDay ?? effectiveCycleDay
    }

    /// Phase for center text — menstrual ONLY from server periodDays.
    private var displayPhase: CyclePhase {
        if let day = exploringDay {
            return cycle.phase(forCycleDay: day)
        }
        return cycle.phase(for: effectiveDate)
            ?? cycle.phase(forCycleDay: min(effectiveCycleDay, cycle.cycleLength))
    }

    /// Days until next period from the displayed date/day.
    private var daysUntilPeriod: Int {
        if let day = exploringDay {
            return cycle.daysUntilPeriod(fromCycleDay: day)
        }
        return cycle.daysUntilPeriod(from: effectiveDate)
    }

    /// Period day number from server block (1-based), nil if not a period day.
    private var periodDayFromServer: Int? {
        if let day = exploringDay,
            let date = Calendar.current.date(
                byAdding: .day,
                value: day - 1,
                to: Calendar.current.startOfDay(for: cycle.cycleStartDate)
            )
        {
            return cycle.periodBlockDay(for: date)
        }
        return cycle.periodBlockDay(for: effectiveDate)
    }

    /// Whether we're looking at a future cycle (offset > 0).
    private var isEstimatedDate: Bool {
        guard let date = calendarDate else { return false }
        return (cycle.cycleDayInfo(for: date)?.offset ?? 0) > 0
    }

    private var isOverdue: Bool {
        exploringDay == nil && calendarDate == nil && todayCycleDay > cycle.cycleLength
    }

    private var overdueDays: Int { todayCycleDay - cycle.cycleLength }

    private var isExploring: Bool {
        isDragging || exploringDay != nil || calendarDate != nil
    }

    // MARK: - Ring Position

    /// The cycle day that positions the orb on the ring.
    /// For estimated dates: uses the effective cycle day within that future cycle.
    /// For overdue: capped at cycleLength.
    private var ringDay: Int {
        if let day = exploringDay { return day }
        return min(effectiveCycleDay, cycle.cycleLength)
    }

    // MARK: - Collapse

    private var hideProgress: Double { min(1, max(0, collapseProgress * 2.5)) }
    private var numberHideProgress: Double { min(1, max(0, (collapseProgress - 0.6) / 0.3)) }

    // MARK: - Center Text

    private var isEstimatedContext: Bool {
        exploringDay != nil || isEstimatedDate
    }

    private var centerTitle: String {
        if displayPhase == .menstrual { return "Period" }
        if isOverdue { return "Period" }
        let days = daysUntilPeriod
        if days <= 0 { return isEstimatedContext ? "Period expected" : "Period" }
        if days == 1 { return "Period" }
        if days <= 7 { return "Period in" }
        if displayPhase == .ovulatory && !isEstimatedDate { return "Fertile" }
        return isEstimatedDate ? "Period in" : displayPhase.displayName
    }

    private var centerSubtitle: String {
        if displayPhase == .menstrual {
            return "Day \(periodDayFromServer ?? min(displayDay, cycle.cycleLength))"
        }
        if isOverdue {
            return overdueDays == 1 ? "1 day late" : "\(overdueDays) days late"
        }
        let days = daysUntilPeriod
        if days <= 0 { return isEstimatedContext ? "today" : "expected today" }
        if days == 1 { return isEstimatedContext ? "starts tomorrow" : "may start\ntomorrow" }
        if days <= 7 { return "\(days) days" }
        if displayPhase == .ovulatory && !isEstimatedDate { return "Window" }
        if isEstimatedDate { return "\(days) days" }
        return "Day \(displayDay)"
    }

    // MARK: - Body

    public var body: some View {
        mainContent
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityValue("Day \(displayDay) of \(cycle.cycleLength)")
            .accessibilityHint("Swipe up or down to explore cycle days")
            .accessibilityAdjustableAction { direction in
                let current = exploringDay ?? todayCycleDay
                switch direction {
                case .increment:
                    exploringDay = min(cycle.cycleLength, current + 1)
                    haptic(.light)
                case .decrement:
                    exploringDay = max(1, current - 1)
                    haptic(.light)
                @unknown default: break
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

    private var accessibilityDescription: String {
        var desc = "\(displayPhase.displayName) phase, day \(displayDay) of \(cycle.cycleLength) day cycle"
        if exploringDay != nil { desc += ", exploring" }
        if let n = cycle.nextPeriodIn, n > 0 { desc += ", \(n) days until next period" }
        if cycle.fertileWindowActive { desc += ", fertile window active" }
        return desc
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            ZStack {
                // Ambient glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                displayPhase.glowColor.opacity(isDragging ? 0.12 : 0.07),
                                displayPhase.glowColor.opacity(0.02),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 60,
                            endRadius: 160
                        )
                    )
                    .frame(width: 380, height: 380)
                    .blur(radius: 20)
                    .opacity(1 - hideProgress)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.6), value: displayPhase)

                // Orbit ring
                CelestialOrbitCanvas(
                    displayDay: ringDay,
                    cycleLength: cycle.cycleLength,
                    bleedingDays: cycle.effectiveBleedingDays,
                    phase: displayPhase,
                    isDragging: isDragging,
                    reduceMotion: reduceMotion,
                    collapseProgress: collapseProgress
                )
                .frame(width: 340, height: 340)
                .allowsHitTesting(false)
                .overlay {
                    if !reduceMotion {
                        CosmicParticleEmitter(displayDay: ringDay, cycleLength: cycle.cycleLength)
                            .frame(width: 340, height: 340)
                            .allowsHitTesting(false)
                            .opacity(1 - hideProgress)
                    }
                }

                // Center text + button
                VStack(spacing: 12) {
                    centerContentView
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: displayDay)

                    if let onLogPeriod, collapseProgress < 0.1 {
                        logPeriodButton(onLogPeriod)
                    }
                }

                // Drag gesture
                gestureOverlay.allowsHitTesting(collapseProgress < 0.1)
            }

            // Context pills
            contextPills
                .opacity(1 - hideProgress)
                .padding(.top, 16)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: displayDay)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .animation(.easeInOut(duration: 0.4), value: displayPhase)
    }

    // MARK: - Center Content

    @ViewBuilder
    private var centerContentView: some View {
        let collapse = hideProgress
        let counterScale: CGFloat = 1.0 + collapse * 1.2

        VStack(spacing: 2) {
            if isDragging {
                dragCenterView(counterScale: counterScale)
            } else {
                contextualCenterView(collapse: collapse, counterScale: counterScale)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDragging)
    }

    private func dragCenterView(counterScale: CGFloat) -> some View {
        let dayNum = periodDayFromServer ?? displayDay
        return VStack(spacing: 0) {
            Text("Day")
                .font(.custom("Raleway-Medium", size: 14))
                .foregroundColor(DesignColors.textSecondary)

            Text("\(dayNum)")
                .font(.custom("Raleway-Bold", size: 48))
                .foregroundStyle(phaseGradient(0.85, 0.75))
                .overlay {
                    Text("\(dayNum)")
                        .font(.custom("Raleway-Bold", size: 48))
                        .foregroundStyle(.ultraThinMaterial)
                        .blendMode(.overlay)
                }
                .contentTransition(.numericText(countsDown: dayNum < todayCycleDay))
                .scaleEffect(1.08)

            Text(displayPhase.displayName)
                .font(.custom("Raleway-SemiBold", size: 13))
                .foregroundColor(displayPhase.orbitColor.opacity(0.8))
                .contentTransition(.numericText())
        }
        .scaleEffect(counterScale)
    }

    @ViewBuilder
    private func contextualCenterView(collapse: Double, counterScale: CGFloat) -> some View {
        // Title
        Text(centerTitle)
            .font(.custom("Raleway-Bold", size: 22))
            .foregroundStyle(phaseGradient(0.9, 0.8))
            .multilineTextAlignment(.center)
            .contentTransition(.numericText())
            .opacity(1 - collapse * 0.5)

        // Subtitle
        Text(centerSubtitle)
            .font(.custom("Raleway-Bold", size: 28))
            .foregroundStyle(phaseGradient(0.85, 0.75))
            .overlay {
                Text(centerSubtitle)
                    .font(.custom("Raleway-Bold", size: 28))
                    .foregroundStyle(.ultraThinMaterial)
                    .blendMode(.overlay)
            }
            .multilineTextAlignment(.center)
            .contentTransition(.numericText())
            .scaleEffect(counterScale)

        // Day pill (hidden for estimated non-period dates)
        if !isEstimatedDate || displayPhase == .menstrual {
            let pillDay = periodDayFromServer ?? displayDay
            HStack(spacing: 6) {
                Text("Day \(pillDay)")
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
        }

        // Estimated badge
        if isEstimatedDate {
            Text("Estimated")
                .font(.custom("Raleway-Medium", size: 10))
                .foregroundColor(DesignColors.textSecondary.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background { Capsule().fill(DesignColors.textSecondary.opacity(0.08)) }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .opacity(1 - collapse)
        }
    }

    // MARK: - Log Period Button

    private func logPeriodButton(_ action: @escaping (Date?) -> Void) -> some View {
        let isOnPeriod = displayPhase == .menstrual
        return Button {
            action(calendarDate)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOnPeriod ? "pencil" : "drop.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(isOnPeriod ? "Edit Period" : "Log Period")
                    .font(.custom("Raleway-SemiBold", size: 13))
            }
            .foregroundColor(CyclePhase.menstrual.orbitColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule().strokeBorder(
                            CyclePhase.menstrual.orbitColor.opacity(0.3),
                            lineWidth: 0.5
                        )
                    }
            }
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    // MARK: - Gesture Overlay

    private var gestureOverlay: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 20

            Color.clear
                .contentShape(Circle().subtracting(Circle().inset(by: 80)))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDrag(value: value, center: center, radius: radius)
                        }
                        .onEnded { _ in
                            lastDragAngle = nil
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                isDragging = false
                                if exploringDay == todayCycleDay { exploringDay = nil }
                            }
                            haptic(.light)
                        }
                )
        }
        .frame(width: 340, height: 340)
    }

    private func handleDrag(value: DragGesture.Value, center: CGPoint, radius: Double) {
        let dx = value.location.x - center.x
        let dy = value.location.y - center.y
        let dist = sqrt(dx * dx + dy * dy)

        guard dist > radius * 0.6 && dist < radius * 1.45 else {
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
            isDragging = true
            calendarDate = nil
            lastDragAngle = angle
            let day = dayForAngle(angle)
            exploringDay = day
            lastHapticPhase = cycle.phase(forCycleDay: day)
            haptic(.light)
            return
        }

        guard let prevAngle = lastDragAngle else {
            lastDragAngle = angle
            return
        }

        var delta = angle - prevAngle
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }

        let dayAngle = (2 * .pi) / Double(max(cycle.cycleLength, 1))
        let daysMoved = Int((delta / dayAngle).rounded())

        if daysMoved != 0 {
            let step = daysMoved > 0 ? 1 : -1
            let current = exploringDay ?? todayCycleDay
            let newDay = current + step
            guard newDay >= 1, newDay <= cycle.cycleLength else {
                lastDragAngle = angle
                return
            }
            exploringDay = newDay
            lastDragAngle = prevAngle + Double(step) * dayAngle
            haptic(.light)

            let newPhase = cycle.phase(forCycleDay: newDay)
            if newPhase != lastHapticPhase {
                lastHapticPhase = newPhase
                haptic(.medium)
            }
        }
    }

    // MARK: - Context Pills

    private var contextPills: some View {
        HStack(spacing: 10) {
            if isExploring {
                if !isDragging {
                    Button {
                        dismissSelection()
                    } label: {
                        pill(
                            icon: "arrow.uturn.backward",
                            text: "Back to today",
                            color: DesignColors.textSecondary
                        )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            } else {
                if let n = cycle.nextPeriodIn {
                    pill(
                        icon: "calendar",
                        text: n == 0 ? "Period today" : "\(n)d until period",
                        color: CyclePhase.menstrual.glowColor
                    )
                }
                if cycle.fertileWindowActive {
                    pill(
                        icon: "sparkles",
                        text: "Fertile window",
                        color: CyclePhase.ovulatory.glowColor
                    )
                }
                if !cycle.fertileWindowActive && cycle.nextPeriodIn == nil {
                    pill(
                        icon: "heart.fill",
                        text: displayPhase.insight,
                        color: displayPhase.glowColor
                    )
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExploring)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isDragging)
    }

    // MARK: - Helpers

    private func pill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            if !icon.isEmpty {
                Image(systemName: icon).font(.system(size: 11, weight: .medium))
            }
            Text(text).font(.custom("Raleway-Medium", size: 12)).lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule().fill(color.opacity(0.08))
                .overlay { Capsule().strokeBorder(color.opacity(0.15), lineWidth: 0.5) }
        }
    }

    private func phaseGradient(_ orbitAlpha: Double, _ glowAlpha: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                displayPhase.orbitColor.opacity(orbitAlpha),
                displayPhase.glowColor.opacity(glowAlpha),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func dismissSelection() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            exploringDay = nil
            calendarDate = nil
            isDragging = false
        }
        haptic(.light)
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func dayForAngle(_ angle: Double) -> Int {
        let normalized = (angle + .pi / 2).truncatingRemainder(dividingBy: 2 * .pi)
        let positive = normalized < 0 ? normalized + 2 * .pi : normalized
        return max(1, min(cycle.cycleLength, Int(positive / (2 * .pi) * Double(cycle.cycleLength)) + 1))
    }
}

// MARK: - Celestial Orbit Canvas

/// Draws the cycle orbit ring: phase-colored arcs, glass effects, and orb marker.
private struct CelestialOrbitCanvas: View {
    let displayDay: Int
    let cycleLength: Int
    let bleedingDays: Int
    let phase: CyclePhase
    let isDragging: Bool
    let reduceMotion: Bool
    var collapseProgress: CGFloat = 0

    @State private var fillAngle: Double = -.pi / 2

    private var wrappedDay: Int {
        guard cycleLength > 0 else { return 1 }
        return ((displayDay - 1) % cycleLength) + 1
    }

    private var targetAngle: Double {
        let cl = Double(max(cycleLength, 1))
        // Place orb at end-of-day so it aligns with phase boundaries.
        // Capped so the last day doesn't wrap to start position.
        let fraction = min(Double(wrappedDay) / cl, 1.0 - 0.5 / cl)
        return fraction * 2 * .pi - .pi / 2
    }

    private var fillTaskKey: Int { displayDay &* 31 &+ cycleLength }

    var body: some View {
        let currentFill = fillAngle
        let collapse = collapseProgress

        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 - 20

            if collapse > 0.05 {
                ctx.opacity = Double(min(1, collapse * 3))
                drawBaseTrack(ctx: &ctx, c: center, r: r)
                ctx.opacity = 1
            }
            drawFilledTrack(ctx: &ctx, c: center, r: r, fill: currentFill)
            drawPhaseArcs(ctx: &ctx, c: center, r: r, fill: currentFill)
            drawOrb(ctx: &ctx, c: center, r: r, angle: currentFill)
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
                let t = min(1.0, Date.now.timeIntervalSince(began) / duration)
                fillAngle = start + (target - start) * (1 - pow(1 - t, 3))
                if t >= 1.0 { break }
                do { try await Task.sleep(for: .milliseconds(16)) } catch { break }
            }
        }
    }

    // MARK: - Drawing

    private let arcW: CGFloat = 14
    private let startAngle = -Double.pi / 2

    private func drawBaseTrack(ctx: inout GraphicsContext, c: CGPoint, r: Double) {
        var path = Path()
        path.addArc(center: c, radius: r, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
        ctx.stroke(
            path,
            with: .color(DesignColors.structure.opacity(0.18)),
            style: StrokeStyle(lineWidth: arcW, lineCap: .round)
        )
    }

    private func drawFilledTrack(ctx: inout GraphicsContext, c: CGPoint, r: Double, fill: Double) {
        guard fill > startAngle + 0.01 else { return }
        // Glass body
        var glass = Path()
        glass.addArc(center: c, radius: r, startAngle: .radians(startAngle), endAngle: .radians(fill), clockwise: false)
        ctx.stroke(
            glass,
            with: .color(DesignColors.structure.opacity(0.10)),
            style: StrokeStyle(lineWidth: arcW, lineCap: .round)
        )
        // Inner rim
        var inner = Path()
        inner.addArc(
            center: c,
            radius: r - Double(arcW / 2) + 0.8,
            startAngle: .radians(startAngle),
            endAngle: .radians(fill),
            clockwise: false
        )
        ctx.stroke(inner, with: .color(Color.white.opacity(0.14)), lineWidth: 0.5)
        // Outer rim
        var outer = Path()
        outer.addArc(
            center: c,
            radius: r + Double(arcW / 2) - 0.8,
            startAngle: .radians(startAngle),
            endAngle: .radians(fill),
            clockwise: false
        )
        ctx.stroke(outer, with: .color(Color.black.opacity(0.04)), lineWidth: 0.5)
    }

    private func drawPhaseArcs(ctx: inout GraphicsContext, c: CGPoint, r: Double, fill: Double) {
        let cl = max(cycleLength, 1)
        let fullCircle = fill >= startAngle + 2 * .pi - 0.05

        for p in CyclePhase.allCases {
            let range = p.dayRange(cycleLength: cycleLength, bleedingDays: bleedingDays)
            let pStart = Double(range.lowerBound - 1) / Double(cl) * 2 * .pi + startAngle
            let pEnd = Double(range.upperBound) / Double(cl) * 2 * .pi + startAngle
            guard fill > pStart else { continue }
            let cEnd = min(pEnd, fill)

            // Phase color
            var body = Path()
            body.addArc(center: c, radius: r, startAngle: .radians(pStart), endAngle: .radians(cEnd), clockwise: false)
            ctx.stroke(
                body,
                with: .color(p.orbitColor.opacity(0.55)),
                style: StrokeStyle(lineWidth: arcW, lineCap: .butt)
            )
            // Inner highlight
            var hi = Path()
            hi.addArc(
                center: c,
                radius: r - Double(arcW / 2) + 1,
                startAngle: .radians(pStart),
                endAngle: .radians(cEnd),
                clockwise: false
            )
            ctx.stroke(hi, with: .color(Color.white.opacity(0.25)), lineWidth: 1.0)
            // Specular
            var sp = Path()
            sp.addArc(
                center: c,
                radius: r - Double(arcW * 0.15),
                startAngle: .radians(pStart),
                endAngle: .radians(cEnd),
                clockwise: false
            )
            ctx.stroke(
                sp,
                with: .color(Color.white.opacity(0.12)),
                style: StrokeStyle(lineWidth: arcW * 0.35, lineCap: .butt)
            )
            // Outer depth
            var od = Path()
            od.addArc(
                center: c,
                radius: r + Double(arcW / 2) - 1,
                startAngle: .radians(pStart),
                endAngle: .radians(cEnd),
                clockwise: false
            )
            ctx.stroke(od, with: .color(p.orbitColor.opacity(0.15)), lineWidth: 0.8)
        }

        // Start fade
        if !fullCircle {
            let fadeAngle = Double.pi * 0.1
            let clampedFade = min(fadeAngle, fill - startAngle)
            guard clampedFade > 0.01 else { return }
            for i in 0..<24 {
                let t = Double(i) / 24
                let tN = Double(i + 1) / 24
                let alpha = pow(1 - t, 3) * 0.9
                var seg = Path()
                seg.addArc(
                    center: c,
                    radius: r,
                    startAngle: .radians(startAngle + t * clampedFade),
                    endAngle: .radians(startAngle + tN * clampedFade),
                    clockwise: false
                )
                ctx.stroke(
                    seg,
                    with: .color(Color(uiColor: .systemBackground).opacity(alpha)),
                    style: StrokeStyle(lineWidth: 12, lineCap: .butt)
                )
            }
        }
    }

    private func drawOrb(ctx: inout GraphicsContext, c: CGPoint, r: Double, angle: Double) {
        let pos = CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r)

        // Bloom
        let bs: Double = 38
        ctx.fill(
            Path(ellipseIn: CGRect(x: pos.x - bs / 2, y: pos.y - bs / 2, width: bs, height: bs)),
            with: .radialGradient(
                Gradient(colors: [phase.glowColor.opacity(0.25), phase.glowColor.opacity(0.06), .clear]),
                center: pos,
                startRadius: 0,
                endRadius: bs / 2
            )
        )

        // Cross rays
        for i in 0..<4 {
            let a = Double(i) * .pi / 4
            let d = 7.0
            var ray = Path()
            ray.move(to: CGPoint(x: pos.x - cos(a) * d, y: pos.y - sin(a) * d))
            ray.addLine(to: CGPoint(x: pos.x + cos(a) * d, y: pos.y + sin(a) * d))
            ctx.stroke(ray, with: .color(.white.opacity(i % 2 == 0 ? 0.5 : 0.25)), lineWidth: 1.2)
        }

        // Gemstone
        let gs: Double = 12
        var gem = ctx
        gem.addFilter(.shadow(color: phase.glowColor.opacity(0.6), radius: 6))
        let gemRect = CGRect(x: -gs / 2, y: -gs / 2, width: gs, height: gs)
        let gemPath = Path(roundedRect: gemRect, cornerRadius: 3)
        gem.translateBy(x: pos.x, y: pos.y)
        gem.rotate(by: .radians(.pi / 4))
        gem.fill(
            gemPath,
            with: .linearGradient(
                Gradient(colors: [.white, phase.orbitColor.opacity(0.7)]),
                startPoint: CGPoint(x: -gs * 0.3, y: -gs * 0.5),
                endPoint: CGPoint(x: gs * 0.3, y: gs * 0.5)
            )
        )
        gem.stroke(gemPath, with: .color(.white.opacity(0.7)), lineWidth: 0.8)
    }
}

// MARK: - Cosmic Particle Emitter

private struct CosmicParticleEmitter: UIViewRepresentable {
    let displayDay: Int
    let cycleLength: Int

    func makeUIView(context: Context) -> CosmicParticleView {
        let v = CosmicParticleView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.displayDay = displayDay
        v.cycleLen = cycleLength
        return v
    }

    func updateUIView(_ v: CosmicParticleView, context: Context) {
        guard v.displayDay != displayDay || v.cycleLen != cycleLength else { return }
        v.displayDay = displayDay
        v.cycleLen = cycleLength
        if Thread.isMainThread { v.rebuildEmitters() } else { DispatchQueue.main.async { v.rebuildEmitters() } }
    }
}

private final class CosmicParticleView: UIView {
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

    func rebuildEmitters() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 20
        guard radius > 10 else { return }

        let startA = -Double.pi / 2
        let fillFrac = Double(displayDay) / Double(max(cycleLen, 1))
        let fillA = fillFrac * 2 * .pi + startA
        let unfilled = startA + 2 * .pi - fillA

        guard unfilled > 0.02 else {
            fieldLayer?.removeFromSuperlayer()
            vortexLayer?.removeFromSuperlayer()
            fieldLayer = nil
            vortexLayer = nil
            return
        }

        if fieldLayer == nil {
            let fl = CAEmitterLayer()
            fl.renderMode = .additive
            let vl = CAEmitterLayer()
            vl.renderMode = .additive
            layer.addSublayer(fl)
            layer.addSublayer(vl)
            fieldLayer = fl
            vortexLayer = vl
        }
        guard let fieldLayer, let vortexLayer else { return }

        let spanFactor = Float(max(0.15, unfilled / (2 * .pi)))

        let roseTaupe = UIColor(red: 0xC8 / 255, green: 0xAD / 255, blue: 0xA7 / 255, alpha: 1)
        let dustyRose = UIColor(red: 0xD6 / 255, green: 0xA5 / 255, blue: 0x9A / 255, alpha: 1)
        let softBlush = UIColor(red: 0xEB / 255, green: 0xCF / 255, blue: 0xC3 / 255, alpha: 1)
        let sandstone = UIColor(red: 0xDE / 255, green: 0xCB / 255, blue: 0xC1 / 255, alpha: 1)

        // Field emitter
        fieldLayer.emitterPosition = center
        fieldLayer.emitterSize = CGSize(width: radius * 2, height: radius * 2)
        fieldLayer.emitterShape = .circle
        fieldLayer.emitterMode = .outline
        fieldLayer.birthRate = spanFactor

        let dust = makeCell(
            birth: 40,
            life: 5.5,
            vel: 4,
            scale: 0.018,
            color: roseTaupe.withAlphaComponent(0.3),
            image: Self.circleImg
        )
        let glow = makeCell(
            birth: 12,
            life: 6.5,
            vel: 3,
            scale: 0.035,
            color: softBlush.withAlphaComponent(0.12),
            image: Self.glowImg
        )
        let sparkle = makeCell(
            birth: 14,
            life: 2.5,
            vel: 2,
            scale: 0.006,
            color: dustyRose.withAlphaComponent(0.4),
            image: Self.circleImg
        )
        let shimmer = makeCell(
            birth: 5,
            life: 4.0,
            vel: 1.5,
            scale: 0.025,
            color: sandstone.withAlphaComponent(0.18),
            image: Self.glowImg
        )
        fieldLayer.emitterCells = [dust, glow, sparkle, shimmer]

        // Mask
        let maskSize = bounds.size
        guard maskSize.width > 0 else { return }
        let fadeA = min(Double.pi * 0.12, unfilled * 0.3)
        let endA = startA + 2 * .pi
        let renderer = UIGraphicsImageRenderer(size: maskSize)
        let maskImg = renderer.image { imgCtx in
            let gc = imgCtx.cgContext
            let lw: CGFloat = 50
            // Fade in
            for i in 0..<12 {
                let t = Double(i) / 12
                let tN = Double(i + 1) / 12
                let seg = UIBezierPath(
                    arcCenter: center,
                    radius: radius,
                    startAngle: fillA + t * fadeA,
                    endAngle: fillA + tN * fadeA,
                    clockwise: true
                )
                gc.setStrokeColor(UIColor(white: 1, alpha: CGFloat(t * t)).cgColor)
                gc.setLineWidth(lw)
                gc.setLineCap(.butt)
                gc.addPath(seg.cgPath)
                gc.strokePath()
            }
            // Full zone
            let fS = fillA + fadeA
            let fE = endA - fadeA
            if fE > fS {
                let full = UIBezierPath(
                    arcCenter: center,
                    radius: radius,
                    startAngle: fS,
                    endAngle: fE,
                    clockwise: true
                )
                gc.setStrokeColor(UIColor.white.cgColor)
                gc.setLineWidth(lw)
                gc.setLineCap(.butt)
                gc.addPath(full.cgPath)
                gc.strokePath()
            }
            // Fade out
            for i in 0..<12 {
                let t = Double(i) / 12
                let tN = Double(i + 1) / 12
                let seg = UIBezierPath(
                    arcCenter: center,
                    radius: radius,
                    startAngle: endA - fadeA + t * fadeA,
                    endAngle: endA - fadeA + tN * fadeA,
                    clockwise: true
                )
                gc.setStrokeColor(UIColor(white: 1, alpha: CGFloat((1 - tN) * (1 - tN))).cgColor)
                gc.setLineWidth(lw)
                gc.setLineCap(.butt)
                gc.addPath(seg.cgPath)
                gc.strokePath()
            }
        }
        let maskLayer = CALayer()
        maskLayer.frame = bounds
        maskLayer.contents = maskImg.cgImage
        fieldLayer.mask = maskLayer

        // Vortex emitter
        let vAngle = fillA + 0.08
        let vx = center.x + cos(vAngle) * radius
        let vy = center.y + sin(vAngle) * radius
        vortexLayer.emitterPosition = CGPoint(x: vx, y: vy)
        vortexLayer.emitterSize = CGSize(width: 44, height: 44)
        vortexLayer.emitterShape = .circle
        vortexLayer.emitterMode = .surface
        vortexLayer.birthRate = spanFactor

        let inward = atan2(center.y - vy, center.x - vx)
        let toward = fillA - .pi / 2
        let absorbA = CGFloat((inward + toward) / 2)

        let aDust = makeCell(
            birth: 22,
            life: 1.0,
            vel: 12,
            scale: 0.015,
            color: roseTaupe.withAlphaComponent(0.35),
            image: Self.circleImg,
            emissionLong: absorbA,
            emissionRange: .pi * 0.6,
            scaleSpeed: -0.015,
            alphaSpeed: -0.6
        )
        let aGlow = makeCell(
            birth: 8,
            life: 0.7,
            vel: 8,
            scale: 0.022,
            color: softBlush.withAlphaComponent(0.18),
            image: Self.glowImg,
            emissionLong: absorbA,
            emissionRange: .pi * 0.5,
            scaleSpeed: -0.025,
            alphaSpeed: -0.9
        )
        let aSparkle = makeCell(
            birth: 8,
            life: 0.5,
            vel: 10,
            scale: 0.005,
            color: dustyRose.withAlphaComponent(0.4),
            image: Self.circleImg,
            emissionLong: absorbA,
            emissionRange: .pi * 0.4,
            scaleSpeed: -0.008,
            alphaSpeed: -1.2
        )
        vortexLayer.emitterCells = [aDust, aGlow, aSparkle]
    }

    private func makeCell(
        birth: Float,
        life: Float,
        vel: CGFloat,
        scale: CGFloat,
        color: UIColor,
        image: UIImage?,
        emissionLong: CGFloat = 0,
        emissionRange: CGFloat = .pi * 2,
        scaleSpeed: CGFloat = -0.001,
        alphaSpeed: Float = -0.04
    ) -> CAEmitterCell {
        let c = CAEmitterCell()
        c.birthRate = birth
        c.lifetime = life
        c.lifetimeRange = life * 0.5
        c.velocity = vel
        c.velocityRange = vel * 2
        c.emissionRange = emissionRange
        c.emissionLongitude = emissionLong
        c.scale = scale
        c.scaleRange = scale * 0.6
        c.scaleSpeed = scaleSpeed
        c.alphaSpeed = alphaSpeed
        c.alphaRange = 0.15
        c.spin = .pi * 0.06
        c.spinRange = .pi * 0.25
        c.color = color.cgColor
        c.contents = image?.cgImage
        return c
    }

    private static let circleImg: UIImage? = {
        let s: CGFloat = 64
        return UIGraphicsImageRenderer(size: CGSize(width: s, height: s)).image { ctx in
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: CGSize(width: s, height: s)))
        }
    }()

    private static let glowImg: UIImage? = {
        let s: CGFloat = 64
        return UIGraphicsImageRenderer(size: CGSize(width: s, height: s)).image { ctx in
            let c = CGPoint(x: s / 2, y: s / 2)
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawRadialGradient(
                    g,
                    startCenter: c,
                    startRadius: 0,
                    endCenter: c,
                    endRadius: s / 2,
                    options: []
                )
            }
        }
    }()
}

// MARK: - CyclePhase Color Extensions

extension CyclePhase {
    var orbitColor: Color {
        switch self {
        case .menstrual: Color(red: 0.79, green: 0.25, blue: 0.38)
        case .follicular: Color(red: 0.36, green: 0.72, blue: 0.65)
        case .ovulatory: Color(red: 0.91, green: 0.66, blue: 0.22)
        case .luteal: Color(red: 0.55, green: 0.49, blue: 0.78)
        }
    }

    var glowColor: Color {
        switch self {
        case .menstrual: Color(red: 0.66, green: 0.19, blue: 0.31)
        case .follicular: Color(red: 0.24, green: 0.60, blue: 0.53)
        case .ovulatory: Color(red: 0.80, green: 0.55, blue: 0.13)
        case .luteal: Color(red: 0.43, green: 0.38, blue: 0.69)
        }
    }

    var gradientColors: [Color] {
        [orbitColor, glowColor]
    }

    fileprivate var uiColor: UIColor {
        switch self {
        case .menstrual: UIColor(red: 0.79, green: 0.25, blue: 0.38, alpha: 1)
        case .follicular: UIColor(red: 0.36, green: 0.72, blue: 0.65, alpha: 1)
        case .ovulatory: UIColor(red: 0.91, green: 0.66, blue: 0.22, alpha: 1)
        case .luteal: UIColor(red: 0.55, green: 0.49, blue: 0.78, alpha: 1)
        }
    }

    fileprivate var uiGlowColor: UIColor {
        switch self {
        case .menstrual: UIColor(red: 0.66, green: 0.19, blue: 0.31, alpha: 1)
        case .follicular: UIColor(red: 0.24, green: 0.60, blue: 0.53, alpha: 1)
        case .ovulatory: UIColor(red: 0.80, green: 0.55, blue: 0.13, alpha: 1)
        case .luteal: UIColor(red: 0.43, green: 0.38, blue: 0.69, alpha: 1)
        }
    }
}

// MARK: - Celestial Mini Bar

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

    private var currentPhase: CyclePhase { CyclePhase(rawValue: phase) ?? .follicular }
    private var fillFraction: Double { Double(cycleDay) / Double(max(cycleLength, 1)) }
    private var orbAngle: Double { fillFraction * 2 * .pi - .pi / 2 }

    public var body: some View {
        HStack(spacing: 14) {
            miniOrbit
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle().fill(currentPhase.orbitColor).frame(width: 6, height: 6)
                    Text("Day \(cycleDay)")
                        .font(.custom("Raleway-Bold", size: 15))
                        .foregroundColor(DesignColors.text)
                    Text("·").foregroundColor(DesignColors.textSecondary)
                    Text(currentPhase.displayName)
                        .font(.custom("Raleway-Medium", size: 15))
                        .foregroundColor(currentPhase.orbitColor)
                }
                if let n = nextPeriodIn, n > 0 {
                    Text("\(n)d until period")
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundColor(DesignColors.textSecondary)
                } else if fertileWindowActive {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.system(size: 10))
                        Text("Fertile window").font(.custom("Raleway-Regular", size: 12))
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
                                colors: [currentPhase.orbitColor.opacity(0.3), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        }
    }

    private var miniOrbit: some View {
        ZStack {
            Circle().stroke(DesignColors.textSecondary.opacity(0.12), lineWidth: 2.5)
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
                .offset(x: cos(orbAngle) * 17, y: sin(orbAngle) * 17)
            Text("\(cycleDay)")
                .font(.custom("Raleway-Bold", size: 13))
                .foregroundStyle(
                    LinearGradient(
                        colors: [currentPhase.orbitColor.opacity(0.85), currentPhase.glowColor.opacity(0.7)],
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
        cycleDay: day,
        cycleLength: 28,
        bleedingDays: 5,
        cycleStartDate: Calendar.current.date(byAdding: .day, value: -(day - 1), to: Date())!,
        currentPhase: phase,
        nextPeriodIn: nextPeriod,
        fertileWindowActive: fertile,
        periodDays: [],
        predictedDays: []
    )
}

#Preview("Follicular - Day 8") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        CelestialCycleView(cycle: previewCycle(8, .follicular, 21, false), exploringDay: .constant(nil))
    }
}

#Preview("Ovulatory - Day 14") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        CelestialCycleView(cycle: previewCycle(14, .ovulatory, 14, true), exploringDay: .constant(nil))
    }
}

#Preview("Menstrual - Day 2") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        CelestialCycleView(cycle: previewCycle(2, .menstrual, nil, false), exploringDay: .constant(nil))
    }
}
