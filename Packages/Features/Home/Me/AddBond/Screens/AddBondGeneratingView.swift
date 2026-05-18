import ComposableArchitecture
import SwiftUI

// MARK: - Add Bond — Generating Step
//
// Loading screen between Sync-the-rhythms and the BondReading.
// The scene is choreographed in four named phases:
//
//   exploring     → two blobs sit apart, gently breathing
//   drifting      → they move into elliptical paths, taking measure
//   approaching   → they close on each other, halos intensify
//   settled       → they come to rest as a paired blob, motion stops
//
// Phase transitions are driven by `withAnimation(.easeInOut(...))`
// on a `@State` `phase` value so the blob positions, rotations,
// halo intensity, and proximity bloom interpolate smoothly between
// waypoints. The status text cycles through 6 stages paced to the
// phase changes. After the final phase lands, a soft success
// haptic fires and the Discover CTA reveals — only then does the
// user advance into the BondReading. There is no auto-advance.

struct AddBondGeneratingView: View {
    @Bindable var store: StoreOf<AddBondFeature>
    let onDismiss: () -> Void

    @State private var phase: GenerationPhase = .exploring
    @State private var statusIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var sceneIn = false
    @State private var statusIn = false
    @State private var discoverIn = false
    @State private var breathing = false
    @State private var particlePhase: Double = 0

    // Hold-to-reveal state. `holdProgress` is driven by a Task
    // while the user is pressing the CTA; it both grows the
    // warm overlay (see `revealFill`) and snaps the final
    // discover action when it reaches 1.0.
    @State private var holdProgress: CGFloat = 0
    @State private var isHolding = false
    @State private var holdDidComplete = false
    @State private var holdTask: Task<Void, Never>?

    private let holdDuration: TimeInterval = 1.3

    private let statusStages: [String] = [
        "Reading the rhythms",
        "Tracing the voices",
        "Mapping the space between",
        "Aligning your patterns",
        "Tuning the harmonics",
        "Your reading is ready",
    ]

    var body: some View {
        GeometryReader { rootGeo in
            // 3-layer stack, back to front:
            //   1. Scene + status + preview + a placeholder
            //      reserving the orb's footprint at the bottom.
            //   2. `revealFill` — the warm circle that grows
            //      from the orb's centre. Covers layer 1 as it
            //      expands.
            //   3. The orb itself — stays on top of the fill so
            //      its progress ring and fingerprint glyph are
            //      always visible.
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    Spacer(minLength: 36)

                    scene
                        .frame(height: 240)

                    Spacer(minLength: 12)

                    statusBlock

                    if phase == .settled {
                        themePreview
                            .padding(.top, 22)
                            .transition(
                                .opacity.combined(with: .offset(y: 14))
                            )
                    }

                    Spacer(minLength: 0)

                    // Footprint reservation for the orb. Now just
                    // 76pt orb + 24pt bottom padding = 100pt; the
                    // hint label below the orb has been dropped
                    // (the fingerprint glyph carries the gesture
                    // affordance on its own).
                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, AppLayout.horizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                revealFill(in: rootGeo.size)

                holdButton
                    .padding(.bottom, 24)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: phase)
        .onAppear { startSequence() }
        .onChange(of: statusIndex) { _, newValue in
            guard newValue < statusStages.count - 1 else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
        }
    }

    // MARK: - Reveal fill
    //
    // Warm circle anchored at the CTA's centre that grows with
    // `holdProgress`. At progress 1.0 it has been scaled large
    // enough to cover the diagonal of the screen from that
    // anchor, so the entire surface goes warm — that's the
    // "doorway" through which the BondReading slides in.

    private func revealFill(in size: CGSize) -> some View {
        // Anchor at the orb's centre. The CTA (orb 76pt + 24pt
        // bottom padding) puts the orb centre ~62pt up from the
        // screen edge. The Liquid Glass reveal radiates from that
        // exact point so it reads as the orb "swelling" outward.
        //
        // CRITICAL: we grow the disc's actual *frame* with
        // `holdProgress` rather than applying `.scaleEffect`.
        // `.glassEffect()` on iOS 26 renders the refraction at
        // the view's drawn size — scaling a small glass disc just
        // stretches the pre-rendered texture and the underlying
        // content stops being sampled. Resizing the frame forces
        // the glass to re-render at the new size every frame,
        // which keeps the live refraction visible to full screen.
        //
        // We wrap the iOS 26 path in `GlassEffectContainer` per
        // Apple's WWDC25 guidance — without the container the
        // refraction sometimes degrades to a flat material. The
        // container also enables proper morph/blend with sibling
        // glass elements should we add any later.
        //
        // No tint at the top level: pulling colour through the
        // glass blurs and dilutes the refraction. The disc reads
        // as pure Liquid Glass; warmth lives in the orb behind
        // it (which is itself warm), so the disc adopts a warm
        // cast from the content it's refracting, not from paint.
        let anchor = CGPoint(x: size.width / 2, y: size.height - 62)
        let diagonal = sqrt(size.width * size.width + size.height * size.height)
        let maxDiameter = diagonal * 2.2
        let baseDiameter: CGFloat = 76
        let currentDiameter = baseDiameter
            + (maxDiameter - baseDiameter) * holdProgress

        return Group {
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    Circle()
                        .fill(.clear)
                        .frame(width: currentDiameter, height: currentDiameter)
                        .glassEffect(.regular, in: .circle)
                }
            } else {
                Color.clear
                    .frame(width: currentDiameter, height: currentDiameter)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                Color.white.opacity(0.35),
                                lineWidth: 0.6
                            )
                    )
                    .clipShape(Circle())
            }
        }
        .position(anchor)
        .opacity(holdProgress > 0 ? 1 : 0)
        .allowsHitTesting(false)
    }

    // MARK: - Scene

    private var scene: some View {
        ZStack {
            ambientParticles
            watermarkLayer
            halosLayer
            proximityBloomLayer
            blobsLayer
        }
        .opacity(sceneIn ? 1 : 0)
        .scaleEffect(sceneIn ? 1.0 : 0.92)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // Drag only nudges the blobs while motion is
                    // alive — once the scene has settled the user
                    // can't pull them apart again.
                    guard phase != .settled else { return }
                    let damped = CGSize(
                        width: value.translation.width.clamped(to: -70...70),
                        height: value.translation.height.clamped(to: -32...32)
                    )
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                        dragOffset = damped
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.62, dampingFraction: 0.66)) {
                        dragOffset = .zero
                    }
                }
        )
    }

    // MARK: - Scene layers

    @ViewBuilder
    private var watermarkLayer: some View {
        // Continuous gentle breath via `repeatForever` on
        // `breathing`. Persists through the settle so the scene
        // never reads as fully static — just calm.
        VennCirclesWatermark(
            strokeColor: DesignColors.accentWarm,
            lineWidth: 1.6,
            opacity: 1.0,
            circleSize: 220,
            overlap: 90
        )
        .scaleEffect(1.0 + (breathing ? 0.04 : 0))
        .opacity(0.13 + (breathing ? 0.04 : 0))
    }

    @ViewBuilder
    private var halosLayer: some View {
        let aOffset = effectiveOffset(base: phase.blobAOffset, dragSign: 1)
        let bOffset = effectiveOffset(base: phase.blobBOffset, dragSign: -1)
        ZStack {
            blobHalo(
                offset: aOffset,
                color: DesignColors.accentWarm,
                intensity: phase.haloIntensity
            )
            blobHalo(
                offset: bOffset,
                color: DesignColors.accentSecondary,
                intensity: phase.haloIntensity
            )
        }
    }

    @ViewBuilder
    private var proximityBloomLayer: some View {
        let aOffset = effectiveOffset(base: phase.blobAOffset, dragSign: 1)
        let bOffset = effectiveOffset(base: phase.blobBOffset, dragSign: -1)
        proximityBloom(
            offsetA: aOffset,
            offsetB: bOffset,
            proximity: phase.proximityStrength
        )
    }

    @ViewBuilder
    private var blobsLayer: some View {
        let aOffset = effectiveOffset(base: phase.blobAOffset, dragSign: 1)
        let bOffset = effectiveOffset(base: phase.blobBOffset, dragSign: -1)
        ZStack {
            Image("BondBlobYou")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(phase.blobARotation))
                .scaleEffect(1.0 + (breathing ? 0.022 : 0))
                .offset(aOffset)

            Image("BondBlobEmpty")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(phase.blobBRotation))
                .scaleEffect(1.0 + (breathing ? -0.022 : 0))
                .offset(bOffset)
        }
    }

    /// Soft radial glow under a blob — wide and heavily blurred so
    /// it reads as ambient light. Intensity scales with the phase
    /// so the halos warm up as the blobs come together.
    private func blobHalo(
        offset: CGSize,
        color: Color,
        intensity: Double
    ) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.32 * intensity),
                        color.opacity(0),
                    ],
                    center: .center,
                    startRadius: 25,
                    endRadius: 95
                )
            )
            .frame(width: 200, height: 200)
            .blur(radius: 20)
            .offset(offset)
            .blendMode(.plusLighter)
    }

    /// Warm bloom that lives at the midpoint between the two blobs.
    /// Squared `strength` keeps it dark until the late approach so
    /// the reveal feels earned.
    private func proximityBloom(
        offsetA: CGSize,
        offsetB: CGSize,
        proximity: Double
    ) -> some View {
        let mid = CGSize(
            width: (offsetA.width + offsetB.width) / 2,
            height: (offsetA.height + offsetB.height) / 2
        )
        let strength = proximity * proximity
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        DesignColors.accentWarm.opacity(0.45 * strength),
                        DesignColors.accentWarm.opacity(0.14 * strength),
                        DesignColors.accentWarm.opacity(0),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 80
                )
            )
            .frame(width: 160, height: 160)
            .blur(radius: 14)
            .offset(mid)
            .blendMode(.plusLighter)
    }

    @ViewBuilder
    private var ambientParticles: some View {
        // Five soft specks in the periphery. A single
        // `repeatForever` linear rotation drives `particlePhase`
        // (30s period — essentially stationary on the screen's
        // timescale, but the slow drift adds life). Sizes / radii
        // / phase offsets are baked into the indexed configs.
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(DesignColors.accentWarm.opacity(0.22))
                    .frame(width: particleConfigs[i].size, height: particleConfigs[i].size)
                    .blur(radius: 2.5)
                    .offset(particleOffset(index: i))
            }
        }
    }

    private func particleOffset(index: Int) -> CGSize {
        let c = particleConfigs[index]
        let angle = c.phase + particlePhase
        return CGSize(
            width: cos(angle) * c.radius,
            height: sin(angle * 1.3) * c.radius * 0.5
        )
    }

    private let particleConfigs: [(radius: Double, phase: Double, size: CGFloat)] = [
        (118, 0,            4.0),
        (138, .pi / 2,      3.0),
        (108, .pi,          5.0),
        (146, 3 * .pi / 2,  3.5),
        (124, .pi / 3,      4.0),
    ]

    // MARK: - Drag-aware offset
    //
    // Combines the phase's base offset with the user's drag, sign
    // inverted between the two blobs so they pull in opposite
    // directions. Drag input is gated off in the settled phase.

    private func effectiveOffset(base: CGSize, dragSign: CGFloat) -> CGSize {
        CGSize(
            width: base.width + dragOffset.width * 0.26 * dragSign,
            height: base.height + dragOffset.height * 0.13 * dragSign
        )
    }

    // MARK: - Status block

    private var statusBlock: some View {
        VStack(spacing: 14) {
            // No eyebrow on this screen — "Generating" felt
            // clinical, "Ready" duplicated the status copy below
            // ("Your reading is ready"). The cycling status text
            // alone now carries the screen's voice.

            ZStack {
                Text(statusStages[statusIndex])
                    .font(AppTypography.cardTitleSecondary)
                    .tracking(-0.2)
                    .foregroundStyle(DesignColors.textPrincipal)
                    .multilineTextAlignment(.center)
                    .id(statusIndex)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 10)),
                            removal: .opacity.combined(with: .offset(y: -8))
                        )
                    )
            }
            .animation(.easeInOut(duration: 0.42), value: statusIndex)
            .frame(minHeight: 32)

            // Progress dots fade out once the scene settles —
            // they belong to the "in progress" mood, not the
            // "ready" mood.
            progressDots
                .padding(.top, 6)
                .opacity(statusIn && phase != .settled ? 1 : 0)
                .animation(.easeInOut(duration: 0.4), value: phase)
        }
        .frame(maxWidth: .infinity)
    }

    private var progressDots: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 7) {
                ForEach(0..<3) { i in
                    let phase = t * 2.0 + Double(i) * 0.45
                    let pulse = (sin(phase) + 1) / 2
                    Circle()
                        .fill(DesignColors.accentWarm)
                        .frame(width: 7, height: 7)
                        .opacity(0.35 + pulse * 0.55)
                        .scaleEffect(0.85 + pulse * 0.25)
                }
            }
        }
    }

    // MARK: - Theme preview
    //
    // Six small pills mirroring the actual `BondTheme.mockSet`
    // subtitles. Functions purely as a teaser — they are not
    // tappable here; the Discover CTA is the way forward. Two
    // rows of three keep the layout compact and centred so the
    // chips read as a paired set rather than a wrapping cloud.

    private var themePreview: some View {
        VStack(spacing: 10) {
            Text("Inside your reading")
                .font(AppTypography.cardEyebrow)
                .tracking(1.4)
                .foregroundStyle(DesignColors.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    chip("Rhythm")
                    chip("Voice")
                    chip("Reciprocity")
                }
                HStack(spacing: 8) {
                    chip("Edges")
                    chip("Becoming")
                    chip("Forecast")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func chip(_ label: String) -> some View {
        Text(label)
            .font(.raleway("SemiBold", size: 12, relativeTo: .footnote))
            .tracking(0.3)
            .foregroundStyle(DesignColors.accentWarm)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(DesignColors.accentWarm.opacity(0.08))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                DesignColors.accentWarm.opacity(0.32),
                                lineWidth: 0.6
                            )
                    )
            )
    }

    // MARK: - Hold-to-reveal CTA
    //
    // Round warm orb with a fingerprint glyph — the press-and-hold
    // affordance reads as biometric/intentional. While the user
    // holds, a linear Task drives `holdProgress` from 0 → 1 over
    // `holdDuration`; the warm `revealFill` radiates from the orb
    // outward, covering the screen at completion. The orb also
    // gains a thin progress ring around it that fills in lockstep,
    // so the user can feel and see how close they are. Releasing
    // mid-hold cancels the task and recoils both the fill and the
    // ring back to zero.
    //
    // Haptics:
    //   • soft impact at press start (intensity 0.55)
    //   • notification.success at completion
    //
    // Layout: round button is the focal element; an uppercase
    // "Hold to discover" hint sits below as a quiet annotation
    // and fades out while the user is holding so the focus stays
    // on the orb's transformation.

    private var holdButton: some View {
        // Glass orb with a fingerprint glyph — the gesture is
        // self-explanatory once the user sees the icon, so the
        // "Hold to discover" hint underneath is dropped. The
        // `nativeGlass(in: Circle(), interactive: true)` wrapper
        // picks up Apple's iOS 26 `.glassEffect(.regular.interactive())`
        // so the disc visibly deforms while pressed, and falls
        // back to `.ultraThinMaterial` + rim + shadow on
        // iOS 17–25.
        Image(systemName: "touchid")
            .font(.system(size: 34, weight: .regular))
            .foregroundStyle(DesignColors.text)
            .frame(width: 76, height: 76)
            .nativeGlass(in: Circle(), interactive: true)
            .scaleEffect(isHolding ? 1.08 : 1.0)
            .animation(
                .spring(response: 0.34, dampingFraction: 0.7),
                value: isHolding
            )
            .contentShape(Circle())
            .onLongPressGesture(
                minimumDuration: holdDuration,
                maximumDistance: 80,
                perform: { completeHold() },
                onPressingChanged: { pressing in
                    if pressing {
                        startHold()
                    } else {
                        cancelHold()
                    }
                }
            )
            .opacity(discoverIn ? 1 : 0)
            .scaleEffect(discoverIn ? 1.0 : 0.94)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Hold to discover")
            .accessibilityHint("Press and hold to reveal your reading")
            .accessibilityAddTraits(.isButton)
    }

    private func startHold() {
        guard !holdDidComplete else { return }
        isHolding = true
        // Soft kick at the start of the press — confirms the
        // gesture has been registered before the fill begins.
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)

        holdTask?.cancel()
        holdTask = Task { @MainActor in
            // 60-step linear ramp. Resetting to 0 on cancel runs
            // through a separate `withAnimation` block in
            // `cancelHold` to keep the recoil tactile.
            //
            // Haptic ticks along the way: every 15 steps (≈0.32s)
            // fires a building impact in sync with the warm fill
            // sweeping outward. Style escalates from `.soft` →
            // `.light` past the half-way mark, and intensity
            // rises with progress, so the user feels the orb
            // "heating up" in their thumb as the screen reveals.
            // The `.success` notification at completion lives in
            // `completeHold()` and caps the build.
            let steps = 60
            let stepDuration = holdDuration / Double(steps)
            for step in 0...steps {
                if Task.isCancelled { return }
                let progress = CGFloat(step) / CGFloat(steps)
                withAnimation(.linear(duration: stepDuration)) {
                    holdProgress = progress
                }

                if step > 0, step < steps, step.isMultiple(of: 15) {
                    let intensity = 0.50 + Double(progress) * 0.45
                    let style: UIImpactFeedbackGenerator.FeedbackStyle =
                        progress < 0.5 ? .soft : .light
                    UIImpactFeedbackGenerator(style: style)
                        .impactOccurred(intensity: intensity)
                }

                try? await Task.sleep(for: .seconds(stepDuration))
            }
        }
    }

    private func cancelHold() {
        // Guard against the trailing `onPressingChanged(false)`
        // that fires immediately after `perform:` completes — we
        // don't want it to rewind the fill we just locked in.
        guard !holdDidComplete else { return }
        isHolding = false
        holdTask?.cancel()
        withAnimation(.easeOut(duration: 0.35)) {
            holdProgress = 0
        }
    }

    private func completeHold() {
        holdDidComplete = true
        isHolding = false
        holdTask?.cancel()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Snap the fill to fully covering the screen — the linear
        // ramp may have ended just below 1.0 due to scheduler
        // jitter; this guarantees a clean warm curtain before the
        // reading slides in.
        withAnimation(.easeOut(duration: 0.18)) {
            holdProgress = 1.0
        }

        // Brief hold on the full fill so the eye registers the
        // colour change before the BondReading overlay starts
        // sliding in over us.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            store.send(.discoverTapped)
        }
    }

    // MARK: - Sequence runner
    //
    // Drives phase + status transitions on a single Task. All
    // animations use `easeInOut` between phases and a soft spring
    // for the final settle — keeps the choreography intentional
    // rather than mechanical (the prior trig-driven orbit version
    // looked equation-y; this one reads as deliberate movement
    // between named beats).

    private func startSequence() {
        withAnimation(.easeOut(duration: 0.9)) { sceneIn = true }
        withAnimation(.easeOut(duration: 0.7).delay(0.25)) { statusIn = true }

        // Continuous gentle breath on the blobs and watermark.
        withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
            breathing = true
        }
        // Slow ambient drift — 30s rotation period is essentially
        // imperceptible in the moment but keeps the scene alive.
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            particlePhase = .pi * 2
        }

        Task { @MainActor in
            // Phase 1 → 2: blobs start drifting outward.
            try? await Task.sleep(for: .milliseconds(1500))
            withAnimation(.easeInOut(duration: 1.6)) {
                phase = .drifting
                statusIndex = 1
            }

            try? await Task.sleep(for: .milliseconds(1100))
            withAnimation(.easeInOut(duration: 0.4)) { statusIndex = 2 }

            // Phase 2 → 3: blobs converge.
            try? await Task.sleep(for: .milliseconds(1100))
            withAnimation(.easeInOut(duration: 1.6)) {
                phase = .approaching
                statusIndex = 3
            }

            try? await Task.sleep(for: .milliseconds(1100))
            withAnimation(.easeInOut(duration: 0.4)) { statusIndex = 4 }

            // Phase 3 → settled: blobs come to rest as a pair.
            // Slightly snappier spring so the landing feels like a
            // small physical "click".
            try? await Task.sleep(for: .milliseconds(1100))
            withAnimation(.spring(response: 1.1, dampingFraction: 0.78)) {
                phase = .settled
                statusIndex = 5
            }

            // Hold on the settled frame so the eye registers the
            // calm before the CTA invites the next move.
            try? await Task.sleep(for: .milliseconds(750))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) {
                discoverIn = true
            }
        }
    }
}

// MARK: - Generation phases
//
// Each phase declares its waypoint values so the view can read
// `phase.blobAOffset`, `phase.haloIntensity`, etc. directly. All
// numeric values were tuned by eye against the intro screen so
// the settled positions echo the BondBlobPair the user saw at the
// start of the flow — the same pair, now resting closer.

private enum GenerationPhase: Equatable, Sendable {
    case exploring
    case drifting
    case approaching
    case settled

    var blobAOffset: CGSize {
        switch self {
        case .exploring:   CGSize(width: -88, height: -6)
        case .drifting:    CGSize(width: -74, height: 18)
        case .approaching: CGSize(width: -46, height: -8)
        case .settled:     CGSize(width: -36, height: 0)
        }
    }

    var blobBOffset: CGSize {
        switch self {
        case .exploring:   CGSize(width: 88, height: 6)
        case .drifting:    CGSize(width: 74, height: -18)
        case .approaching: CGSize(width: 46, height: 8)
        case .settled:     CGSize(width: 36, height: 0)
        }
    }

    var blobARotation: Double {
        switch self {
        case .exploring:   -6
        case .drifting:    -16
        case .approaching: -14
        case .settled:     -12
        }
    }

    var blobBRotation: Double {
        switch self {
        case .exploring:   134
        case .drifting:    148
        case .approaching: 144
        case .settled:     140
        }
    }

    var haloIntensity: Double {
        switch self {
        case .exploring:   0.45
        case .drifting:    0.55
        case .approaching: 0.72
        case .settled:     0.88
        }
    }

    /// 0...1 — drives the proximity bloom at the midpoint. Kept
    /// low in early phases so the bloom doesn't compete with the
    /// blobs themselves; saturates in the settled phase.
    var proximityStrength: Double {
        switch self {
        case .exploring:   0.02
        case .drifting:    0.08
        case .approaching: 0.35
        case .settled:     0.88
        }
    }
}

// MARK: - Comparable.clamped helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    AddBondView(
        store: .init(initialState: AddBondFeature.State(step: .generating)) {
            AddBondFeature()
        },
        onDismiss: {}
    )
}
