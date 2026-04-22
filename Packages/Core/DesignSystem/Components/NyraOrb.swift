import SwiftUI

// MARK: - Nyra Orb
//
// Cycle's AI companion, ported from the "Nyra" character-sheet design
// handoff. Six expressive states — every one of them a subtle mood
// change (gradient, breath, micro-expression), never a contortion.
//
// Visual layering (top → bottom):
//   1. Outer halo (breathing / pulsing blur)
//   2. Listening rings (expanding concentric borders)
//   3. Ground contact shadow (anchors the orb in space)
//   4. Main sphere — radial gradient (ivory → blush → rose → aria-warm
//      → terracotta → mauve → cocoa-deep), plus breath / speak pulse
//   5. Inner ring — only while thinking
//   6. Top specular (soft blurred ellipse)
//   7. Tight hot spot (bright reflection)
//   8. Lower refraction glow (warm return-light)
//   9. Rim light (1px inner highlight)
//  10. Face — triangle eyes by default; arcs for comforting / celebrating;
//      dots rotate inside while thinking.
//
// Palette derived 100% from the app's existing warm tokens — no new
// colours introduced. See Cycle's design system for the canonical hexes.

public struct NyraOrb: View {

    // MARK: State

    public enum Mood: String, Sendable, CaseIterable {
        case idle
        case listening
        case speaking
        case thinking
        case comforting
        case celebrating
    }

    // MARK: Props

    public let size: CGFloat
    public let mood: Mood
    public let showFace: Bool
    public let speed: Double
    /// When `false`, Nyra freezes entirely — breath, drift, blink,
    /// gaze, glance all stop. Use this to park her when her view is
    /// visually covered (e.g. calendar overlay, tab not focused) so
    /// her `repeatForever` animations don't keep hammering SwiftUI's
    /// view graph in the background.
    public let active: Bool

    public init(
        size: CGFloat = 200,
        mood: Mood = .idle,
        showFace: Bool? = nil,
        speed: Double = 1,
        active: Bool = true
    ) {
        self.size = size
        self.mood = mood
        // Face disappears below 32px — per the character-sheet scale rules.
        self.showFace = showFace ?? (size >= 32)
        self.speed = max(0.1, speed)
        self.active = active
    }

    // MARK: Animated state

    @State private var breathScale: CGFloat = 1.0
    @State private var blink: Bool = false
    @State private var gaze: CGSize = .zero
    /// Occasionally toggles to `true` so the eyes "pop open" for a
    /// moment before relaxing back into the closed-smile arc. Gives
    /// Nyra the sense that she glanced at the message.
    @State private var eyesOpen: Bool = false
    // Task handles so we can cancel every loop on disappear / scene
    // background — otherwise Nyra would keep blinking, drifting and
    // glancing off-screen and burn battery + CPU for nothing.
    @State private var blinkTask: Task<Void, Never>?
    @State private var gazeTask: Task<Void, Never>?
    @State private var glanceTask: Task<Void, Never>?
    // Drift is driven by SwiftUI's own animation interpolation rather
    // than recomputed every TimelineView tick — far smoother even on
    // busy frames (no stutter when paired with the blur-heavy sphere).
    @State private var driftPhaseX: CGFloat = 0
    @State private var driftPhaseY: CGFloat = 0
    /// Siri-style blob morph phase — drives the silhouette deformation.
    /// Runs off a single SwiftUI `repeatForever` animation so the blob
    /// interpolates smoothly on the render thread, not a per-frame tick.
    @State private var blobPhase: CGFloat = 0
    @State private var blobPhase2: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Body

    public var body: some View {
        ZStack {
            // Static / slow-animating layers — don't need per-frame ticks.
            haloLayer(t: 0)
            groundShadow

            // Liquid-glass body — sphere layers composited inside a
            // subtle blob-morphing silhouette so the form breathes and
            // deforms organically instead of reading as a rigid disc.
            ZStack {
                mainSphere
                rimOcclusion
                baseOcclusion
                topSpecular
                tightHotSpot
                lowerRefractionGlow
            }
            .frame(width: size * 0.84, height: size * 0.84)
            .mask(
                BlobShape(phase: blobPhase, phase2: blobPhase2, bulge: 0.035)
                    .frame(width: size * 0.84, height: size * 0.84)
            )
            .scaleEffect(breathScale)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.6),
                value: mood
            )

            rimLight

            // Fast / per-frame layers — RAF pulses, rotating dots, ring
            // expansion. Isolated so the heavy blur stack above isn't
            // rebuilt every frame.
            if mood == .listening || mood == .thinking || mood == .speaking {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    ZStack {
                        if mood == .listening {
                            listeningRings(t: t)
                        }
                        if mood == .thinking {
                            innerRing(phase: 0.5 + 0.5 * sin(t * 2.2))
                        }
                        if mood == .speaking {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: size * 0.84, height: size * 0.84)
                                .scaleEffect(CGFloat(speakingPulse(t: t)))
                        }
                    }
                }
            }

            if showFace {
                if mood == .thinking {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                        thinkingDots(t: context.date.timeIntervalSinceReferenceDate)
                    }
                } else {
                    faceEyes
                        .offset(
                            x: gaze.width,
                            y: gaze.height
                        )
                }
            }
        }
        .frame(width: size, height: size)
        // When Nyra glances at the message, the ENTIRE orb (sphere,
        // halo, face, specular) tilts and shifts together — not just
        // the eyes — so it reads as a real head-turn, not a detached
        // eye animation.
        // Head-turn illusion without rotation3DEffect's lateral squash:
        // the sphere stays perfectly round, the face features shift
        // across its surface, and the whole orb leans slightly right.
        // Single `.animation(_, value: eyesOpen)` on the outermost
        // modifier makes everything (face, specular, hot spot, lean,
        // offset) animate as one transaction — no staggered timings.
        .offset(
            x: driftPhaseX * 3,
            y: driftPhaseY * 4
        )
        .accessibilityElement()
        .accessibilityLabel("Nyra")
        .accessibilityValue(mood.rawValue)
        .onAppear {
            if active { startAllLoops() }
        }
        .onDisappear { stopAllLoops() }
        .onChange(of: mood) { _, _ in
            if active { startBreath() }
        }
        .onChange(of: active) { _, nowActive in
            if nowActive {
                startAllLoops()
            } else {
                stopAllLoops()
            }
        }
    }

    /// Kick off every ambient loop — called on appear and when the
    /// scene returns to active from background.
    private func startAllLoops() {
        startBreath()
        startBlink()
        startGaze()
        startEyesGlance()
        startDrift()
        startBlobMorph()
    }

    /// Siri-style blob morph — two interpolating phases running at
    /// different speeds so the silhouette wobbles asymmetrically and
    /// never repeats exactly. Driven by SwiftUI animations so it's
    /// smooth on the render thread without per-frame ticks.
    private func startBlobMorph() {
        guard !reduceMotion else {
            blobPhase = 0
            blobPhase2 = 0
            return
        }
        blobPhase = 0
        blobPhase2 = 0
        withAnimation(.easeInOut(duration: 4.8 / speed).repeatForever(autoreverses: true)) {
            blobPhase = 1
        }
        withAnimation(.easeInOut(duration: 7.2 / speed).repeatForever(autoreverses: true)) {
            blobPhase2 = 1
        }
    }

    /// Cancel every active task/animation so Nyra stops consuming CPU
    /// when her view leaves the screen or the app backgrounds.
    private func stopAllLoops() {
        blinkTask?.cancel(); blinkTask = nil
        gazeTask?.cancel(); gazeTask = nil
        glanceTask?.cancel(); glanceTask = nil
        blink = false
        gaze = .zero
        eyesOpen = false
    }

    // MARK: - Breath cycle

    private func startBreath() {
        guard !reduceMotion else {
            breathScale = 1.0
            return
        }
        // Siri-style breath — more pronounced amplitude so the sphere
        // feels actively alive. No face means pulse carries the
        // personality, so we lean into it.
        let (duration, amplitude): (Double, CGFloat) = {
            switch mood {
            case .idle:         return (3.6 / speed, 0.035)
            case .listening:    return (2.2 / speed, 0.045)
            case .speaking:     return (2.8 / speed, 0.040)
            case .thinking:     return (2.4 / speed, 0.035)
            case .comforting:   return (3.4 / speed, 0.050)
            case .celebrating:  return (1.4 / speed, 0.075)
            }
        }()
        breathScale = 1.0
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            breathScale = 1.0 + amplitude
        }
    }

    private func startBlink() {
        guard !reduceMotion else { return }
        blinkTask?.cancel()
        blinkTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((2.6 / speed + Double.random(in: 0...0.9)) * 1_000_000_000))
                blink = true
                try? await Task.sleep(nanoseconds: 130_000_000)
                blink = false
            }
        }
    }

    private func startGaze() {
        guard !reduceMotion else { return }
        gazeTask?.cancel()
        gazeTask = Task { @MainActor in
            while !Task.isCancelled {
                let angle = Double.random(in: 0...(2 * .pi))
                let radius = Double.random(in: 0.8...2.2)
                let offset = CGSize(
                    width: cos(angle) * radius,
                    height: sin(angle) * radius * 0.5
                )
                withAnimation(.easeOut(duration: 0.45)) {
                    gaze = offset
                }
                try? await Task.sleep(nanoseconds: UInt64((2.4 / speed) * 1_000_000_000))
            }
        }
    }

    /// Speaking mood keeps the pill eyes open by default — Nyra is
    /// addressing the user, so she's engaged and attentive. Every so
    /// often she "blinks" (the pills squish shut for ~110ms). Other
    /// moods keep the resting arc expression and never auto-open.
    private func startEyesGlance() {
        guard !reduceMotion, mood == .speaking else {
            eyesOpen = false
            return
        }
        glanceTask?.cancel()
        // Open pills immediately on appear — default resting state for
        // the speaking mood. Small delay so the sphere settles first.
        glanceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 0.4...0.9) * 1_000_000_000))
            withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                eyesOpen = true
            }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 3.5...6.5) * 1_000_000_000))
                blink = true
                try? await Task.sleep(nanoseconds: 110_000_000)
                blink = false
            }
        }
    }

    /// Floaty idle drift — two-axis SwiftUI animation with slightly
    /// different durations so the motion never repeats exactly. Runs
    /// entirely via the animation system, no per-frame ticks.
    private func startDrift() {
        guard !reduceMotion else {
            driftPhaseX = 0
            driftPhaseY = 0
            return
        }
        driftPhaseX = -1
        driftPhaseY = -1
        withAnimation(.easeInOut(duration: 3.8 / speed).repeatForever(autoreverses: true)) {
            driftPhaseX = 1
        }
        withAnimation(.easeInOut(duration: 5.4 / speed).repeatForever(autoreverses: true)) {
            driftPhaseY = 1
        }
    }

    // MARK: - Per-frame derived values

    private func idleDrift(t: TimeInterval) -> CGSize {
        guard !reduceMotion else { return .zero }
        return CGSize(
            width: sin(t * 0.7) * 3,
            height: cos(t * 0.5) * 4 + sin(t * 1.3) * 1.5
        )
    }

    private func speakingPulse(t: TimeInterval) -> Double {
        1 + (sin(t * 9) * 0.025 + sin(t * 3.2) * 0.015)
    }

    // MARK: - Palettes

    private var sphereGradient: RadialGradient {
        RadialGradient(
            stops: sphereStops,
            center: UnitPoint(x: 0.68, y: 0.24),
            startRadius: 0,
            endRadius: size * 0.5
        )
    }

    // Warm, in-palette gradient — ivory → blush → peach → warm accent.
    // Mauve/cocoa kept out entirely so Nyra sits inside the app's rose-
    // gold / peach tonal range (matches CycleApp's "warm gradients"
    // design language) instead of introducing a cool purple/grey edge.
    private var sphereStops: [Gradient.Stop] {
        switch mood {
        case .listening:
            return [
                Gradient.Stop(color: Color(hex: 0xFFFFFF), location: 0.00),
                Gradient.Stop(color: Color(hex: 0xFEF0E6), location: 0.18),
                Gradient.Stop(color: Color(hex: 0xF8D4C3), location: 0.44),
                Gradient.Stop(color: Color(hex: 0xE8A58E), location: 0.72),
                Gradient.Stop(color: Color(hex: 0xCE7D68), location: 1.00)
            ]
        case .speaking, .celebrating:
            return [
                Gradient.Stop(color: Color(hex: 0xFFFFFF), location: 0.00),
                Gradient.Stop(color: Color(hex: 0xFEEADA), location: 0.22),
                Gradient.Stop(color: Color(hex: 0xF7C7B1), location: 0.52),
                Gradient.Stop(color: Color(hex: 0xE89478), location: 0.82),
                Gradient.Stop(color: Color(hex: 0xC97D68), location: 1.00)
            ]
        case .thinking:
            return [
                Gradient.Stop(color: Color(hex: 0xFDF5EC), location: 0.00),
                Gradient.Stop(color: Color(hex: 0xF2D4C1), location: 0.32),
                Gradient.Stop(color: Color(hex: 0xD9A091), location: 0.64),
                Gradient.Stop(color: Color(hex: 0xB3776A), location: 1.00)
            ]
        case .idle, .comforting:
            return [
                Gradient.Stop(color: Color(hex: 0xFFFBF4), location: 0.00),
                Gradient.Stop(color: Color(hex: 0xFEE5D4), location: 0.22),
                Gradient.Stop(color: Color(hex: 0xF5C1AA), location: 0.52),
                Gradient.Stop(color: Color(hex: 0xDE957E), location: 0.82),
                Gradient.Stop(color: Color(hex: 0xBF7A66), location: 1.00)
            ]
        }
    }

    private var haloColor: Color {
        switch mood {
        case .listening:   return Color(hex: 0xE8A58E).opacity(0.45)
        case .speaking:    return Color(hex: 0xF7C7B1).opacity(0.55)
        case .thinking:    return Color(hex: 0xD9A091).opacity(0.42)
        case .comforting:  return Color(hex: 0xF5C1AA).opacity(0.48)
        case .celebrating: return Color(hex: 0xE8A58E).opacity(0.58)
        case .idle:        return Color(hex: 0xE8A58E).opacity(0.40)
        }
    }

    // MARK: - Layers

    @ViewBuilder
    private func haloLayer(t: TimeInterval) -> some View {
        let base = size * 0.22
        let listenBoost = mood == .listening ? CGFloat(0.04 + 0.04 * sin(t * 3.9)) : 0
        Circle()
            .fill(
                RadialGradient(
                    colors: [haloColor, .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.62
                )
            )
            .frame(width: size + base * 2, height: size + base * 2)
            .blur(radius: 24)
            .opacity(haloPulseOpacity(t: t))
            .scaleEffect(1 + listenBoost)
    }

    private func haloPulseOpacity(t: TimeInterval) -> Double {
        guard !reduceMotion else { return 0.75 }
        switch mood {
        case .listening:  return 0.6 + 0.4 * (0.5 + 0.5 * sin(t * 3.9))
        case .speaking:   return 0.6 + 0.25 * (0.5 + 0.5 * sin(t * 6.2))
        default:          return 0.55 + 0.4 * (0.5 + 0.5 * sin(t * 2.1))
        }
    }

    @ViewBuilder
    private func listeningRings(t: TimeInterval) -> some View {
        let phase1 = (t.truncatingRemainder(dividingBy: 2.2 / speed)) / (2.2 / speed)
        let phase2 = ((t + 0.7).truncatingRemainder(dividingBy: 2.2 / speed)) / (2.2 / speed)
        Group {
            ring(color: Color(hex: 0xD98D7A).opacity(0.4), phase: phase1)
            ring(color: Color(hex: 0xB87294).opacity(0.35), phase: phase2)
        }
    }

    @ViewBuilder
    private func ring(color: Color, phase: Double) -> some View {
        Circle()
            .strokeBorder(color, lineWidth: 1.5)
            .frame(width: size, height: size)
            .scaleEffect(CGFloat(1 + phase * 0.4))
            .opacity(1 - phase)
    }

    private var groundShadow: some View {
        // Liquid-glass ripple base — three layers: a tight dark contact
        // core, a wider warm bloom, and an extra-wide soft ripple halo
        // that suggests the orb is sitting on a reflective surface.
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        stops: [
                            Gradient.Stop(color: Color(hex: 0x7A5040).opacity(0.34), location: 0.0),
                            Gradient.Stop(color: Color(hex: 0x7A5040).opacity(0.12), location: 0.55),
                            Gradient.Stop(color: .clear, location: 1.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.34
                    )
                )
                .frame(width: size * 0.66, height: size * 0.12)
                .blur(radius: 8)

            Ellipse()
                .fill(
                    RadialGradient(
                        stops: [
                            Gradient.Stop(color: Color(hex: 0xA86B55).opacity(0.18), location: 0.0),
                            Gradient.Stop(color: Color(hex: 0xA86B55).opacity(0.05), location: 0.6),
                            Gradient.Stop(color: .clear, location: 1.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size * 0.98, height: size * 0.18)
                .blur(radius: 18)

            // Extra-wide ripple halo — barely visible, gives the sense
            // of the orb resting on a surface that the light spills onto.
            Ellipse()
                .fill(
                    RadialGradient(
                        stops: [
                            Gradient.Stop(color: Color(hex: 0xE69A86).opacity(0.12), location: 0.0),
                            Gradient.Stop(color: Color(hex: 0xE69A86).opacity(0.03), location: 0.7),
                            Gradient.Stop(color: .clear, location: 1.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size * 1.25, height: size * 0.22)
                .blur(radius: 24)
        }
        .offset(y: size * 0.46)
    }

    private var mainSphere: some View {
        // A single radial gradient carries the "volume" (highlight →
        // shadow) — no stacked stroke rings, which previously produced
        // the visible "ring layer" artefact around the sphere edge.
        Circle()
            .fill(sphereGradient)
            .frame(width: size * 0.84, height: size * 0.84)
            .shadow(color: haloColor.opacity(0.6), radius: size * 0.22, x: 0, y: 0)
            .shadow(color: Color(hex: 0xA86B55).opacity(0.28), radius: size * 0.10, x: 0, y: size * 0.09)
    }

    /// Siri-style inner aura — a low-opacity conic gradient rotating
    /// slowly inside the sphere. The warm palette (peach + blush +
    /// amber + rose-wine) keeps it in-brand; mood shifts the mix.
    private var conicAura: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let period: Double = {
                switch mood {
                case .celebrating: return 10.0
                case .speaking:    return 16.0
                case .listening:   return 18.0
                case .thinking:    return 14.0
                case .comforting:  return 22.0
                case .idle:        return 24.0
                }
            }()
            let angle = (t.truncatingRemainder(dividingBy: period) / period) * 360.0

            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: auraColors),
                            center: .center,
                            angle: .degrees(angle)
                        )
                    )
                    .frame(width: size * 0.84, height: size * 0.84)
                    .blendMode(.plusLighter)
                    .opacity(0.35)

                // Counter-rotating second aura at a different rate —
                // creates the "swirling aurora" quality Siri has.
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: auraColors.reversed()),
                            center: .center,
                            angle: .degrees(-angle * 0.6)
                        )
                    )
                    .frame(width: size * 0.84, height: size * 0.84)
                    .blendMode(.plusLighter)
                    .opacity(0.22)
                    .blur(radius: size * 0.05)
            }
        }
    }

    /// Warm-palette aura colors shifted by mood. Stays in-brand: no
    /// cool blues or purples — all within the peach / amber / rose /
    /// wine family so Nyra reads consistently even while breathing
    /// through colors.
    private var auraColors: [Color] {
        switch mood {
        case .speaking, .celebrating:
            return [
                Color(hex: 0xFFD4B8),
                Color(hex: 0xF7B098),
                Color(hex: 0xE89478),
                Color(hex: 0xD06A5A),
                Color(hex: 0xFFD4B8)
            ]
        case .listening:
            return [
                Color(hex: 0xFDE9D5),
                Color(hex: 0xF5C6B2),
                Color(hex: 0xE8A490),
                Color(hex: 0xC8826F),
                Color(hex: 0xFDE9D5)
            ]
        case .thinking:
            return [
                Color(hex: 0xF2D4C1),
                Color(hex: 0xD9A091),
                Color(hex: 0xB3776A),
                Color(hex: 0xE2B29D),
                Color(hex: 0xF2D4C1)
            ]
        case .comforting:
            return [
                Color(hex: 0xFEE5D4),
                Color(hex: 0xF5C1AA),
                Color(hex: 0xDE957E),
                Color(hex: 0xF0C0A8),
                Color(hex: 0xFEE5D4)
            ]
        case .idle:
            return [
                Color(hex: 0xFEE9DA),
                Color(hex: 0xF6CBB7),
                Color(hex: 0xE8A58E),
                Color(hex: 0xFAD7C4),
                Color(hex: 0xFEE9DA)
            ]
        }
    }

    @ViewBuilder
    private func innerRing(phase: Double) -> some View {
        Circle()
            .trim(from: 0, to: 0.22)
            .stroke(
                LinearGradient(
                    colors: [.clear, Color(hex: 0xFDFCF7).opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )
            .overlay(
                Circle()
                    .strokeBorder(Color(hex: 0xFDFCF7).opacity(0.3 + phase * 0.4), lineWidth: 1.5)
            )
            .frame(width: size * 0.56, height: size * 0.56)
            .rotationEffect(.degrees(phase * 360))
    }

    private var topSpecular: some View {
        // Broad diffuse highlight — multi-stop falloff so the light
        // fades into the sphere gradually instead of stopping abruptly
        // at the ellipse edge. Normal compositing (no plusLighter) so
        // it sits ON the sphere, not blown-out over it.
        Ellipse()
            .fill(
                RadialGradient(
                    stops: [
                        Gradient.Stop(color: Color.white.opacity(0.55), location: 0.0),
                        Gradient.Stop(color: Color.white.opacity(0.22), location: 0.35),
                        Gradient.Stop(color: Color.white.opacity(0.06), location: 0.70),
                        Gradient.Stop(color: Color.white.opacity(0.0), location: 1.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.26
                )
            )
            .frame(width: size * 0.52, height: size * 0.34)
            .blur(radius: 7)
            .offset(x: -size * 0.08, y: -size * 0.22)
    }

    private var tightHotSpot: some View {
        // Tight, crisp specular kick — small diameter, near-pure white
        // at center so the sphere reads as a *polished* surface with a
        // real light source, not a diffuse glow.
        Circle()
            .fill(
                RadialGradient(
                    stops: [
                        Gradient.Stop(color: Color.white.opacity(0.95), location: 0.0),
                        Gradient.Stop(color: Color.white.opacity(0.55), location: 0.35),
                        Gradient.Stop(color: Color.white.opacity(0.12), location: 0.75),
                        Gradient.Stop(color: Color.white.opacity(0.0), location: 1.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.045
                )
            )
            .frame(width: size * 0.09, height: size * 0.09)
            .blur(radius: 1.1)
            .offset(x: -size * 0.07, y: -size * 0.22)
    }

    /// Rim shadow — darkens the outer ring of the sphere so the edge
    /// falls off into volume instead of fading linearly. This is the
    /// "terminator" in traditional shading: opposite side of the light
    /// source gets a warm cocoa tint that reads as a real 3D falloff.
    private var rimOcclusion: some View {
        Circle()
            .fill(
                RadialGradient(
                    stops: [
                        Gradient.Stop(color: .clear, location: 0.55),
                        Gradient.Stop(color: Color(hex: 0x6A4234).opacity(0.24), location: 0.84),
                        Gradient.Stop(color: Color(hex: 0x3E2518).opacity(0.42), location: 1.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.42
                )
            )
            .frame(width: size * 0.84, height: size * 0.84)
    }

    /// Base occlusion — concentrated dark pool at bottom-center (the
    /// side opposite the light source). Gives the sphere *weight* —
    /// without this, the bottom half reads as warm mid-tone floating,
    /// not as a real object sitting under the light.
    private var baseOcclusion: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    stops: [
                        Gradient.Stop(color: Color(hex: 0x3A2218).opacity(0.40), location: 0.0),
                        Gradient.Stop(color: Color(hex: 0x3A2218).opacity(0.14), location: 0.55),
                        Gradient.Stop(color: .clear, location: 1.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.3
                )
            )
            .frame(width: size * 0.70, height: size * 0.38)
            .blur(radius: 10)
            .offset(x: size * 0.06, y: size * 0.22)
            .mask(
                Circle()
                    .frame(width: size * 0.84, height: size * 0.84)
            )
    }

    private var lowerRefractionGlow: some View {
        // Ambient warm return-light, very subtle so the bottom half
        // just glows instead of lighting up.
        Ellipse()
            .fill(
                RadialGradient(
                    stops: [
                        Gradient.Stop(color: Color(hex: 0xFFDBC2).opacity(0.22), location: 0.0),
                        Gradient.Stop(color: Color(hex: 0xFFDBC2).opacity(0.08), location: 0.55),
                        Gradient.Stop(color: .clear, location: 1.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.26
                )
            )
            .frame(width: size * 0.52, height: size * 0.20)
            .blur(radius: 9)
            .offset(x: size * 0.04, y: size * 0.2)
    }

    private var rimLight: some View {
        // No stroked rim — the discrete arc was reading as a hard
        // unblended line on top of the sphere. The specular highlight
        // and hot spot already carry all the volume we need, and the
        // outer shadow + halo handle the edge softening.
        EmptyView()
    }

    // MARK: - Face

    @ViewBuilder
    private var faceEyes: some View {
        // Liquid-glass style — two narrow vertical ivory pills, close
        // together. The pills are small relative to the sphere and sit
        // on the surface like embedded light-catchers, the way the
        // reference Ripple-orb's eyes do.
        let eyeColor = Color(hex: 0xFDFCF7)
        let eyeW = size * 0.045
        let eyeH = size * 0.105
        let shadow: Shadow = .init(
            color: Color(hex: 0x2D1E16).opacity(0.32),
            radius: 1.2,
            x: 0,
            y: 0.8
        )

        HStack(spacing: size * 0.055) {
            Capsule()
                .fill(eyeColor)
                .frame(width: eyeW, height: eyeH)

            Capsule()
                .fill(eyeColor)
                .frame(width: eyeW, height: eyeH)
        }
        .scaleEffect(y: blink ? 0.08 : 1.0, anchor: .center)
        .animation(.easeInOut(duration: 0.13), value: blink)
        .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
        .offset(y: -size * 0.015)
    }

    /// Almond-pill eye with twin 4-point twinkle sparkles — Sora-style.
    /// The stars (instead of plain dots) give Nyra real dimensional
    /// life, and make the eye feel like it catches the light from
    /// more than one source at once.
    @ViewBuilder
    private func eye(color: Color, sparkle: Color) -> some View {
        let eyeW = size * 0.095
        let eyeH = size * 0.145
        let bigStar = size * 0.050
        let smallStar = size * 0.026
        ZStack {
            Capsule()
                .fill(color)
                .frame(width: eyeW, height: eyeH)

            // Big 4-point twinkle — upper area of the eye, biggest
            // light catch, where the viewer's gaze lands first.
            Twinkle()
                .fill(sparkle)
                .frame(width: bigStar, height: bigStar)
                .offset(
                    x: -eyeW * 0.12 + gaze.width * 0.3,
                    y: -eyeH * 0.20 + gaze.height * 0.3
                )

            // Small 4-point twinkle — offset to the lower-right, adds
            // the "two lights reflecting" quality that reads as wet eye.
            Twinkle()
                .fill(sparkle.opacity(0.85))
                .frame(width: smallStar, height: smallStar)
                .offset(
                    x: eyeW * 0.20 + gaze.width * 0.3,
                    y: eyeH * 0.22 + gaze.height * 0.3
                )
        }
        .shadow(color: color.opacity(0.32), radius: 1.4, x: 0, y: 1)
    }

    /// Smile curvature amount. Capped low across the board — every
    /// mood is a *suggestion* of a smile, never a grin. Editorial,
    /// not emoji.
    private var smileAmount: Double {
        switch mood {
        case .celebrating: return 0.35
        case .speaking:    return 0.22
        case .comforting:  return 0.14
        case .listening:   return 0.18
        case .idle:        return 0.16
        case .thinking:    return 0.15
        }
    }

    @ViewBuilder
    private func thinkingDots(t: TimeInterval) -> some View {
        let base = 2.0 * Double.pi * (t.truncatingRemainder(dividingBy: 2.2) / 2.2)
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let angle = base + Double(i) * (2 * .pi / 3)
                Circle()
                    .fill(Color(hex: 0xFDFCF7))
                    .frame(width: size * 0.024, height: size * 0.024)
                    .offset(
                        x: cos(angle) * size * 0.06,
                        y: sin(angle) * size * 0.06
                    )
            }
        }
        .shadow(color: Color(hex: 0x2D1E16).opacity(0.5), radius: 1.2, x: 0, y: 1)
    }
}

// MARK: - Face shapes

private struct EyeArc: Shape {
    enum Direction { case up, down }
    let direction: Direction

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let start = CGPoint(x: rect.minX, y: rect.midY)
        let end = CGPoint(x: rect.maxX, y: rect.midY)
        let apex: CGPoint = direction == .up
            ? CGPoint(x: rect.midX, y: rect.minY)
            : CGPoint(x: rect.midX, y: rect.maxY)
        p.move(to: start)
        p.addQuadCurve(to: end, control: apex)
        return p
    }
}

/// Siri-style wobbling blob — a near-circle with 8 control points,
/// each offset radially by a phase-driven sine. Two phases running
/// at different rates (`phase` and `phase2`) break symmetry so the
/// silhouette never repeats exactly. Animating both phases via
/// `AnimatablePair` lets SwiftUI interpolate the shape on the render
/// thread instead of per-frame in Swift.
private struct BlobShape: Shape {
    var phase: CGFloat
    var phase2: CGFloat
    /// How far each control point can bulge — 0 is a perfect circle.
    var bulge: CGFloat = 0.055

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, phase2) }
        set {
            phase = newValue.first
            phase2 = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2

        let segments = 8
        var points: [CGPoint] = []
        for i in 0..<segments {
            let theta = Double(i) / Double(segments) * 2.0 * .pi
            let wobble1 = sin(theta * 3 + Double(phase) * 2 * .pi)
            let wobble2 = cos(theta * 2 + Double(phase2) * 2 * .pi)
            let radial = 1.0 + CGFloat(wobble1 + wobble2 * 0.6) * bulge * 0.5
            let rr = r * radial
            points.append(CGPoint(
                x: cx + CGFloat(cos(theta)) * rr,
                y: cy + CGFloat(sin(theta)) * rr
            ))
        }

        // Smooth catmull-rom-ish curve through the 8 points using
        // quadratic beziers with midpoints as anchors — produces a
        // continuous, blob-like outline without hard corners.
        let first = points[0]
        let midFirst = CGPoint(
            x: (first.x + points[1].x) / 2,
            y: (first.y + points[1].y) / 2
        )
        p.move(to: midFirst)
        for i in 0..<segments {
            let current = points[(i + 1) % segments]
            let next = points[(i + 2) % segments]
            let mid = CGPoint(
                x: (current.x + next.x) / 2,
                y: (current.y + next.y) / 2
            )
            p.addQuadCurve(to: mid, control: current)
        }
        p.closeSubpath()
        return p
    }
}

/// 4-point twinkle (✧) — a star with concave sides. Used as the eye
/// catchlight on Sora-style companion faces: 4 cardinal points with
/// curved waists between them. The `waist` parameter controls how
/// deeply the sides bow in (0 = diamond/rhombus, higher = sharper star).
private struct Twinkle: Shape {
    var waist: CGFloat = 0.28

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let w = rect.width / 2
        let h = rect.height / 2

        // 4 cardinal points (N, E, S, W) with quadratic bezier curves
        // bowing inward between them — gives the classic twinkle look.
        let top    = CGPoint(x: cx, y: cy - h)
        let right  = CGPoint(x: cx + w, y: cy)
        let bottom = CGPoint(x: cx, y: cy + h)
        let left   = CGPoint(x: cx - w, y: cy)

        // Control points near center — the smaller the offset, the
        // sharper the star. `waist` maps 0 → diamond, 1 → cross.
        let cw = w * waist
        let ch = h * waist

        p.move(to: top)
        p.addQuadCurve(to: right, control: CGPoint(x: cx + cw, y: cy - ch))
        p.addQuadCurve(to: bottom, control: CGPoint(x: cx + cw, y: cy + ch))
        p.addQuadCurve(to: left, control: CGPoint(x: cx - cw, y: cy + ch))
        p.addQuadCurve(to: top, control: CGPoint(x: cx - cw, y: cy - ch))
        p.closeSubpath()
        return p
    }
}

/// Smile curve — a soft upward arc. `amount` scales the bow depth,
/// with 0 producing a flat line and 1 producing a near half-circle.
private struct SmileArc: Shape {
    let amount: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let clamped = max(0, min(1, amount))
        let start = CGPoint(x: rect.minX, y: rect.minY)
        let end = CGPoint(x: rect.maxX, y: rect.minY)
        let apex = CGPoint(x: rect.midX, y: rect.minY + rect.height * clamped)
        p.move(to: start)
        p.addQuadCurve(to: end, control: apex)
        return p
    }
}

// MARK: - Internal shadow helper

private struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Preview

#Preview("Nyra · States") {
    ScrollView {
        VStack(spacing: 32) {
            ForEach(NyraOrb.Mood.allCases, id: \.self) { mood in
                VStack(spacing: 10) {
                    NyraOrb(size: 200, mood: mood)
                    Text(mood.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 18) {
                ForEach([24, 40, 72, 120, 200], id: \.self) { sz in
                    VStack {
                        NyraOrb(size: CGFloat(sz))
                        Text("\(sz)px").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(40)
    }
    .background(Color(hex: 0xFDFCF7))
}
