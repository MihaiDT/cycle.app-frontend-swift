import SwiftUI

// MARK: - Celestial Cycle View

/// Premium orbital cycle visualization with full accessibility support.
/// Interactive: drag along the orbit to explore days, haptic feedback at phase crossings,
/// tap phases for detail tooltips. Canvas + TimelineView at 30fps with multi-layer particle system.
/// Supports VoiceOver adjustable action and reduced-motion preferences.
public struct CelestialCycleView: View {
    public let cycleDay: Int
    public let cycleLength: Int
    public let phase: String
    public let nextPeriodIn: Int?
    public let fertileWindowActive: Bool
    public var collapseProgress: CGFloat

    @State private var exploringDay: Int?
    @State private var isDragging = false
    @State private var lastHapticPhase: CyclePhase?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        cycleDay: Int,
        cycleLength: Int,
        phase: String,
        nextPeriodIn: Int?,
        fertileWindowActive: Bool,
        collapseProgress: CGFloat = 0
    ) {
        self.cycleDay = cycleDay
        self.cycleLength = cycleLength
        self.phase = phase
        self.nextPeriodIn = nextPeriodIn
        self.fertileWindowActive = fertileWindowActive
        self.collapseProgress = collapseProgress
    }

    private var currentPhase: CyclePhase {
        CyclePhase(rawValue: phase) ?? .follicular
    }

    private var displayDay: Int {
        exploringDay ?? cycleDay
    }

    private var displayPhase: CyclePhase {
        phaseForDay(displayDay)
    }

    /// Whether the circle is mostly collapsed into bar form
    private var isCollapsed: Bool { collapseProgress > 0.85 }

    public var body: some View {
        mainContent
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityValue("Day \(displayDay) of \(cycleLength)")
            .accessibilityHint("Swipe up or down to explore cycle days")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    let next = min(cycleLength, (exploringDay ?? cycleDay) + 1)
                    exploringDay = next
                    triggerHaptic(.light)
                case .decrement:
                    let prev = max(1, (exploringDay ?? cycleDay) - 1)
                    exploringDay = prev
                    triggerHaptic(.light)
                @unknown default:
                    break
                }
            }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        let circleHeight: CGFloat = CGFloat(270 * (1 - collapseProgress) + 44 * collapseProgress)
        let contentOpacity = Double(max(0, 1 - collapseProgress * 2.5))

        VStack(spacing: 0) {
            ZStack {
                // Ambient glow — fades out
                ambientGlow
                    .opacity(contentOpacity)
                    .animation(.easeInOut(duration: 0.6), value: displayPhase)

                // The morphing canvas (circle → bar)
                CelestialOrbitCanvas(
                    cycleDay: cycleDay,
                    cycleLength: cycleLength,
                    phase: currentPhase,
                    exploringDay: exploringDay,
                    isDragging: isDragging,
                    reduceMotion: reduceMotion,
                    collapseProgress: collapseProgress
                )
                .overlay {
                    if !reduceMotion && collapseProgress < 0.4 {
                        CosmicParticleEmitter(
                            cycleDay: cycleDay,
                            cycleLength: cycleLength,
                            exploringDay: exploringDay
                        )
                        .frame(width: 260, height: 260)
                        .opacity(contentOpacity)
                        .allowsHitTesting(false)
                    }
                }

                // Center content — fades out
                if collapseProgress < 0.5 {
                    centerContent
                        .opacity(contentOpacity)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: displayDay)
                }

                // Gesture overlay — only when circle is visible
                if collapseProgress < 0.3 {
                    gestureOverlay
                }
            }
            .frame(height: circleHeight)
            .clipped()

            if collapseProgress < 0.3 {
                contextPills
                    .padding(.top, 16)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: displayDay)
                    .opacity(Double(max(0, 1 - collapseProgress * 4)))
            }
        }
        .padding(.vertical, CGFloat(20 * max(0, 1 - collapseProgress * 2)))
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.4), value: displayPhase)
    }

    private var accessibilityDescription: String {
        let phaseName = displayPhase.displayName
        let exploring = exploringDay != nil
        var desc = "\(phaseName) phase, day \(displayDay) of \(cycleLength) day cycle"
        if exploring { desc += ", exploring" }
        if let daysUntil = nextPeriodIn, daysUntil > 0 {
            desc += ", \(daysUntil) days until next period"
        }
        if fertileWindowActive { desc += ", fertile window active" }
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
            .frame(width: 300, height: 300)
            .blur(radius: 20)
    }

    // MARK: - Gesture Overlay

    private var gestureOverlay: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 20

            Color.clear
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let dx = value.location.x - center.x
                            let dy = value.location.y - center.y
                            let distFromCenter = sqrt(dx * dx + dy * dy)

                            guard abs(distFromCenter - radius) < 35 else {
                                if isDragging {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        isDragging = false
                                    }
                                }
                                return
                            }

                            let angle = atan2(dy, dx)
                            let day = dayForAngle(angle)

                            if !isDragging {
                                isDragging = true
                                lastHapticPhase = phaseForDay(day)
                                triggerHaptic(.light)
                            }

                            if day != exploringDay {
                                exploringDay = day
                                let newPhase = phaseForDay(day)
                                if newPhase != lastHapticPhase {
                                    lastHapticPhase = newPhase
                                    triggerHaptic(.medium)
                                }
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                isDragging = false
                                if exploringDay == cycleDay {
                                    exploringDay = nil
                                }
                            }
                            triggerHaptic(.light)
                        }
                )

        }
        .frame(width: 260, height: 260)
    }

    private func dismissSelection() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            exploringDay = nil
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

    private var centerContent: some View {
        VStack(spacing: 4) {
            Text(displayPhase.description)
                .font(.custom("Raleway-Regular", size: 11))
                .foregroundColor(DesignColors.textSecondary)
                .contentTransition(.numericText())

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Day")
                    .font(.custom("Raleway-Medium", size: 16))
                    .foregroundColor(DesignColors.textSecondary)

                Text("\(displayDay)")
                    .font(.custom("Raleway-Bold", size: isDragging ? 48 : 44))
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
                            .font(.custom("Raleway-Bold", size: isDragging ? 48 : 44))
                            .foregroundStyle(.ultraThinMaterial)
                            .blendMode(.overlay)
                    }
                    .contentTransition(.numericText(countsDown: displayDay < cycleDay))
                    .scaleEffect(isDragging ? 1.08 : 1.0)
            }

            Text(displayPhase.displayName)
                .font(.custom("Raleway-SemiBold", size: 13))
                .foregroundColor(displayPhase.orbitColor.opacity(0.8))
                .contentTransition(.numericText())
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDragging)
    }

    // MARK: - Context Pills

    private var isExploring: Bool {
        isDragging || exploringDay != nil
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
                if let daysUntil = nextPeriodIn {
                    contextPill(
                        icon: "calendar",
                        text: daysUntil == 0 ? "Period today" : "\(daysUntil)d until period",
                        color: CyclePhase.menstrual.glowColor
                    )
                }

                if fertileWindowActive {
                    contextPill(
                        icon: "sparkles",
                        text: "Fertile window",
                        color: CyclePhase.ovulatory.glowColor
                    )
                }

                if !fertileWindowActive && nextPeriodIn == nil {
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
        return max(1, min(cycleLength, Int(fraction * Double(cycleLength)) + 1))
    }

    private func phaseForDay(_ day: Int) -> CyclePhase {
        for p in CyclePhase.allCases {
            if p.dayRange(cycleLength: cycleLength).contains(day) { return p }
        }
        return .luteal
    }
}

// MARK: - Celestial Orbit Canvas

/// Canvas that draws the cycle orbit and smoothly morphs between
/// a circular ring (collapseProgress=0) and a horizontal bar (collapseProgress=1).
/// Every point on the circle interpolates to a corresponding point on the bar.
private struct CelestialOrbitCanvas: View {
    let cycleDay: Int
    let cycleLength: Int
    let phase: CyclePhase
    let exploringDay: Int?
    let isDragging: Bool
    let reduceMotion: Bool
    var collapseProgress: CGFloat = 0

    @State private var fillAngle: Double = -.pi / 2

    private var displayDay: Int { exploringDay ?? cycleDay }

    private var targetAngle: Double {
        exactAngle(forDay: displayDay + 1, of: cycleLength)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 : 1.0 / 30.0)) { timeline in
            let time = reduceMotion ? 0.0 : timeline.date.timeIntervalSinceReferenceDate
            let currentFill = fillAngle
            let morph = Double(collapseProgress)

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let circleRadius: Double = 110 // fixed radius for the circle form

                drawFilledTrack(context: &context, center: center, radius: circleRadius, fillAngle: currentFill, size: size, morph: morph)
                drawPhaseArcs(context: &context, center: center, radius: circleRadius, fillAngle: currentFill, size: size, morph: morph)
                drawOrbMarker(context: &context, center: center, radius: circleRadius, time: time, orbAngle: currentFill, size: size, morph: morph)
            }
        }
        .task(id: displayDay) {
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

    // MARK: - Morphing Helpers

    /// Converts a cycle fraction (0…1) to a point that smoothly morphs
    /// from a circular position to a horizontal bar position.
    private func morphedPoint(
        fraction: Double,
        center: CGPoint,
        radius: Double,
        offsetRadius: Double = 0,
        size: CGSize,
        morph: Double
    ) -> CGPoint {
        let angle = fraction * 2 * .pi - .pi / 2
        let r = radius + offsetRadius
        let cx = center.x + cos(angle) * r
        let cy = center.y + sin(angle) * r

        let barInset: Double = 10
        let lx = barInset + fraction * (size.width - 2 * barInset)
        let ly = size.height / 2

        return CGPoint(
            x: cx + (lx - cx) * morph,
            y: cy + (ly - cy) * morph
        )
    }

    /// Creates a Path that morphs from an arc segment to a line segment.
    /// Samples enough points for smooth curvature during the transition.
    private func morphedArcPath(
        startFraction: Double,
        endFraction: Double,
        center: CGPoint,
        radius: Double,
        offsetRadius: Double = 0,
        size: CGSize,
        morph: Double
    ) -> Path {
        let span = endFraction - startFraction
        let segments = max(Int(span * 60), 12)
        var path = Path()
        for i in 0...segments {
            let t = Double(i) / Double(segments)
            let frac = startFraction + t * span
            let pt = morphedPoint(
                fraction: frac, center: center, radius: radius,
                offsetRadius: offsetRadius, size: size, morph: morph
            )
            if i == 0 { path.move(to: pt) }
            else { path.addLine(to: pt) }
        }
        return path
    }

    // MARK: - Liquid Glass Track (morphing)

    private func drawFilledTrack(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        fillAngle: Double,
        size: CGSize,
        morph: Double
    ) {
        let startAngle = -Double.pi / 2
        let arcWidth: CGFloat = CGFloat(10 - 4 * morph) // 10 → 6

        guard fillAngle > startAngle + 0.01 else { return }

        let fillFrac = (fillAngle + .pi / 2) / (2 * .pi)

        // --- Layer 1: Frosted glass body ---
        let glassPath = morphedArcPath(
            startFraction: 0, endFraction: fillFrac,
            center: center, radius: radius, size: size, morph: morph
        )
        context.stroke(
            glassPath,
            with: .color(Color(red: 0xDE / 255.0, green: 0xCB / 255.0, blue: 0xC1 / 255.0).opacity(0.10)),
            style: StrokeStyle(lineWidth: arcWidth, lineCap: .round)
        )

        // Glass detail layers fade out during morph
        let glassOpacity = max(0.0, 1.0 - morph * 2.5)
        guard glassOpacity > 0.01 else { return }

        // --- Layer 2: Inner rim highlight ---
        let innerPath = morphedArcPath(
            startFraction: 0, endFraction: fillFrac,
            center: center, radius: radius,
            offsetRadius: Double(-arcWidth / 2 + 0.8), size: size, morph: morph
        )
        context.stroke(
            innerPath,
            with: .color(Color.white.opacity(0.14 * glassOpacity)),
            lineWidth: 0.5
        )

        // --- Layer 3: Outer rim depth ---
        let outerPath = morphedArcPath(
            startFraction: 0, endFraction: fillFrac,
            center: center, radius: radius,
            offsetRadius: Double(arcWidth / 2 - 0.8), size: size, morph: morph
        )
        context.stroke(
            outerPath,
            with: .color(Color.black.opacity(0.04 * glassOpacity)),
            lineWidth: 0.5
        )
    }

    // MARK: - Phase Arcs (morphing glass effect)

    private func drawPhaseArcs(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        fillAngle: Double,
        size: CGSize,
        morph: Double
    ) {
        let startAngle = -Double.pi / 2
        let fullCircle = fillAngle >= startAngle + 2 * .pi - 0.05
        let arcWidth: CGFloat = CGFloat(10 - 4 * morph)
        let glassOpacity = max(0.0, 1.0 - morph * 2.5)
        let fillFrac = (fillAngle + .pi / 2) / (2 * .pi)

        // Background track (visible as morph progresses)
        if morph > 0.05 {
            let bgPath = morphedArcPath(
                startFraction: 0, endFraction: 1.0,
                center: center, radius: radius, size: size, morph: morph
            )
            context.stroke(
                bgPath,
                with: .color(Color(red: 0xDE / 255.0, green: 0xCB / 255.0, blue: 0xC1 / 255.0).opacity(0.12 * morph)),
                style: StrokeStyle(lineWidth: arcWidth, lineCap: .round)
            )
        }

        for phaseItem in CyclePhase.allCases {
            let range = phaseItem.dayRange(cycleLength: cycleLength)
            let startFrac = Double(range.lowerBound - 1) / Double(max(cycleLength, 1))
            let endFrac = Double(range.upperBound) / Double(max(cycleLength, 1))

            guard fillFrac > startFrac else { continue }
            let filledEndFrac = min(endFrac, fillFrac)

            // --- Layer 1: Phase color ---
            let bodyPath = morphedArcPath(
                startFraction: startFrac, endFraction: filledEndFrac,
                center: center, radius: radius, size: size, morph: morph
            )
            context.stroke(
                bodyPath,
                with: .color(phaseItem.orbitColor.opacity(0.55)),
                style: StrokeStyle(lineWidth: arcWidth, lineCap: .butt)
            )

            // Glass layers fade out
            if glassOpacity > 0.01 {
                // --- Layer 2: Inner highlight ---
                let innerPath = morphedArcPath(
                    startFraction: startFrac, endFraction: filledEndFrac,
                    center: center, radius: radius,
                    offsetRadius: Double(-arcWidth / 2 + 1), size: size, morph: morph
                )
                context.stroke(
                    innerPath,
                    with: .color(Color.white.opacity(0.25 * glassOpacity)),
                    lineWidth: 1.0
                )

                // --- Layer 3: Specular shine ---
                let shinePath = morphedArcPath(
                    startFraction: startFrac, endFraction: filledEndFrac,
                    center: center, radius: radius,
                    offsetRadius: Double(-arcWidth * 0.15), size: size, morph: morph
                )
                context.stroke(
                    shinePath,
                    with: .color(Color.white.opacity(0.12 * glassOpacity)),
                    style: StrokeStyle(lineWidth: arcWidth * 0.35, lineCap: .butt)
                )

                // --- Layer 4: Outer depth ---
                let outerPath = morphedArcPath(
                    startFraction: startFrac, endFraction: filledEndFrac,
                    center: center, radius: radius,
                    offsetRadius: Double(arcWidth / 2 - 1), size: size, morph: morph
                )
                context.stroke(
                    outerPath,
                    with: .color(phaseItem.orbitColor.opacity(0.15 * glassOpacity)),
                    lineWidth: 0.8
                )
            }
        }

        // Smooth fade at the start (only in circle mode)
        if !fullCircle && morph < 0.3 {
            let fadeAngle = Double.pi * 0.1
            let clampedFade = min(fadeAngle, fillAngle - startAngle)
            guard clampedFade > 0.01 else { return }

            let fadeFrac = clampedFade / (2 * .pi)
            let fadeSteps = 24
            let fadeOpacity = max(0.0, 1.0 - morph * 3.3)

            for i in 0..<fadeSteps {
                let t = Double(i) / Double(fadeSteps)
                let tNext = Double(i + 1) / Double(fadeSteps)
                let segStartFrac = t * fadeFrac
                let segEndFrac = tNext * fadeFrac

                let inv = 1.0 - t
                let eraseAlpha = inv * inv * inv * 0.9 * fadeOpacity

                let seg = morphedArcPath(
                    startFraction: segStartFrac, endFraction: segEndFrac,
                    center: center, radius: radius, size: size, morph: morph
                )
                context.stroke(
                    seg,
                    with: .color(Color(uiColor: .systemBackground).opacity(eraseAlpha)),
                    style: StrokeStyle(lineWidth: 12, lineCap: .butt)
                )
            }
        }
    }

    // MARK: - Orb Marker (morphing)

    private func drawOrbMarker(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        time: Double,
        orbAngle: Double,
        size: CGSize,
        morph: Double
    ) {
        let displayDay = exploringDay ?? cycleDay
        let orbPhase = phaseForDay(displayDay)
        let orbFraction = (orbAngle + .pi / 2) / (2 * .pi)

        let orbCenter = morphedPoint(
            fraction: orbFraction, center: center, radius: radius,
            size: size, morph: morph
        )

        let scale = 1.0 - morph * 0.35 // shrink slightly when collapsed

        // --- Soft outer bloom ---
        let bloomSize = 38.0 * scale
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

        // --- Cross light rays (fade out during morph) ---
        let rayOpacity = max(0.0, 1.0 - morph * 2.0)
        if rayOpacity > 0.01 {
            let rayLen = 14.0 * scale
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
                    with: .color(.white.opacity((i % 2 == 0 ? 0.5 : 0.25) * rayOpacity)),
                    lineWidth: rayWidth
                )
            }
        }

        // --- Main gemstone ---
        let gemSize = 12.0 * scale
        var gemCtx = context
        gemCtx.addFilter(.shadow(color: orbPhase.glowColor.opacity(0.6), radius: 6 * scale))

        let gemRect = CGRect(x: -gemSize / 2, y: -gemSize / 2, width: gemSize, height: gemSize)
        let cornerRadius = 3.0 * (1 - morph) + (gemSize / 2) * morph // square→circle
        let gemPath = Path(roundedRect: gemRect, cornerRadius: cornerRadius)
        gemCtx.translateBy(x: orbCenter.x, y: orbCenter.y)
        let rotation = (.pi / 4) * (1 - morph) // diamond→upright
        gemCtx.rotate(by: .radians(rotation))

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
        let fraction = Double(day - 1) / Double(max(total, 1))
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
            if p.dayRange(cycleLength: cycleLength).contains(day) { return p }
        }
        return .luteal
    }
}

// MARK: - Cosmic Particle Emitter (CAEmitterLayer)

/// Hardware-accelerated particle emitter that renders cosmic dust along the unfilled
/// arc of the cycle. Uses multiple CAEmitterCells per phase for a realistic nebula effect.
private struct CosmicParticleEmitter: UIViewRepresentable {
    let cycleDay: Int
    let cycleLength: Int
    let exploringDay: Int?

    private var displayDay: Int { exploringDay ?? cycleDay }

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
        uiView.rebuildEmitters()
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

// MARK: - Cycle Progress Bar (collapsed header)

/// Horizontal progress bar that appears when the circle scrolls out of view.
/// Shows phase colors, day-of-week labels, and highlights the current day.
public struct CycleProgressBar: View {
    public let cycleDay: Int
    public let cycleLength: Int
    public let phase: String

    public init(cycleDay: Int, cycleLength: Int, phase: String) {
        self.cycleDay = cycleDay
        self.cycleLength = cycleLength
        self.phase = phase
    }

    private var currentPhase: CyclePhase {
        CyclePhase(rawValue: phase) ?? .follicular
    }

    // Build array of (startFraction, endFraction, phase) for each cycle phase
    private var phaseSegments: [(start: CGFloat, end: CGFloat, phase: CyclePhase)] {
        CyclePhase.allCases.compactMap { p in
            let range = p.dayRange(cycleLength: cycleLength)
            let start = CGFloat(range.lowerBound - 1) / CGFloat(cycleLength)
            let end = CGFloat(range.upperBound) / CGFloat(cycleLength)
            return (start, end, p)
        }
    }

    private var currentDayFraction: CGFloat {
        CGFloat(cycleDay - 1) / CGFloat(max(cycleLength - 1, 1))
    }

    // Days of the week centered around today
    private var weekDays: [(label: String, dayNum: Int, isToday: Bool)] {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"

        return (-3...3).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            let label = formatter.string(from: date).uppercased()
            let day = cycleDay + offset
            return (label, day, offset == 0)
        }
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Day-of-week labels
            HStack(spacing: 0) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { _, item in
                    Text(item.label)
                        .font(.custom("Raleway-SemiBold", size: 10))
                        .foregroundColor(item.isToday ? currentPhase.orbitColor : DesignColors.textSecondary.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }

            // Progress bar with phase colors
            GeometryReader { geo in
                let width = geo.size.width
                let barHeight: CGFloat = 6

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(DesignColors.structure.opacity(0.15))
                        .frame(height: barHeight)

                    // Phase color segments
                    Canvas { context, size in
                        let h = size.height
                        let r = h / 2

                        for seg in phaseSegments {
                            let x1 = seg.start * size.width
                            let x2 = seg.end * size.width

                            let segPath = Path(roundedRect: CGRect(
                                x: x1, y: 0,
                                width: x2 - x1, height: h
                            ), cornerRadius: seg.start == 0 || seg.end == 1 ? r : 0)

                            context.fill(segPath, with: .color(seg.phase.orbitColor.opacity(0.55)))
                        }

                        // Glass highlight on filled portion
                        let fillX = currentDayFraction * size.width
                        let fillRect = CGRect(x: 0, y: 0, width: fillX, height: h * 0.4)
                        context.fill(
                            Path(roundedRect: fillRect, cornerRadius: r),
                            with: .color(.white.opacity(0.15))
                        )
                    }
                    .frame(height: barHeight)
                    .clipShape(Capsule())

                    // Current day indicator
                    Circle()
                        .fill(currentPhase.orbitColor)
                        .frame(width: 12, height: 12)
                        .shadow(color: currentPhase.glowColor.opacity(0.5), radius: 4)
                        .overlay {
                            Circle()
                                .fill(.white.opacity(0.3))
                                .frame(width: 5, height: 5)
                        }
                        .offset(x: currentDayFraction * width - 6)
                }
                .frame(height: 12)
            }
            .frame(height: 12)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Scroll Offset Preference Key

public struct ScrollOffsetPreferenceKey: PreferenceKey {
    public static let defaultValue: CGFloat = 0
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Previews

#Preview("Follicular - Day 8") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        CelestialCycleView(
            cycleDay: 8,
            cycleLength: 28,
            phase: "follicular",
            nextPeriodIn: 21,
            fertileWindowActive: false
        )
        .padding()
    }
}

#Preview("Ovulatory - Day 14") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        CelestialCycleView(
            cycleDay: 14,
            cycleLength: 28,
            phase: "ovulatory",
            nextPeriodIn: 14,
            fertileWindowActive: true
        )
        .padding()
    }
}

#Preview("Menstrual - Day 2") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        CelestialCycleView(
            cycleDay: 2,
            cycleLength: 28,
            phase: "menstrual",
            nextPeriodIn: nil,
            fertileWindowActive: false
        )
        .padding()
    }
}
