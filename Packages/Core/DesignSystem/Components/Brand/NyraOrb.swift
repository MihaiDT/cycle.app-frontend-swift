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

    @State var breathScale: CGFloat = 1.0
    @State var blink: Bool = false
    @State var gaze: CGSize = .zero
    /// Occasionally toggles to `true` so the eyes "pop open" for a
    /// moment before relaxing back into the closed-smile arc. Gives
    /// Nyra the sense that she glanced at the message.
    @State var eyesOpen: Bool = false
    // Task handles so we can cancel every loop on disappear / scene
    // background — otherwise Nyra would keep blinking, drifting and
    // glancing off-screen and burn battery + CPU for nothing.
    @State var blinkTask: Task<Void, Never>?
    @State var gazeTask: Task<Void, Never>?
    @State var glanceTask: Task<Void, Never>?
    // Drift is driven by SwiftUI's own animation interpolation rather
    // than recomputed every TimelineView tick — far smoother even on
    // busy frames (no stutter when paired with the blur-heavy sphere).
    @State var driftPhaseX: CGFloat = 0
    @State var driftPhaseY: CGFloat = 0
    /// Siri-style blob morph phase — drives the silhouette deformation.
    /// Runs off a single SwiftUI `repeatForever` animation so the blob
    /// interpolates smoothly on the render thread, not a per-frame tick.
    @State var blobPhase: CGFloat = 0
    @State var blobPhase2: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

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

}
