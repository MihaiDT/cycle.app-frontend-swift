import SwiftUI

// MARK: - NyraOrb › Palettes + Layers + Face
//
// Visual layer renderers (halo, rings, sphere, aura, specular, face)
// extracted from NyraOrb.swift. Each method is a pure view builder
// reading only from `self` @State; no side effects.

extension NyraOrb {

    // MARK: - Palettes

    var sphereGradient: RadialGradient {
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
    var sphereStops: [Gradient.Stop] {
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

    var haloColor: Color {
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
    func haloLayer(t: TimeInterval) -> some View {
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

    func haloPulseOpacity(t: TimeInterval) -> Double {
        guard !reduceMotion else { return 0.75 }
        switch mood {
        case .listening:  return 0.6 + 0.4 * (0.5 + 0.5 * sin(t * 3.9))
        case .speaking:   return 0.6 + 0.25 * (0.5 + 0.5 * sin(t * 6.2))
        default:          return 0.55 + 0.4 * (0.5 + 0.5 * sin(t * 2.1))
        }
    }

    @ViewBuilder
    func listeningRings(t: TimeInterval) -> some View {
        let phase1 = (t.truncatingRemainder(dividingBy: 2.2 / speed)) / (2.2 / speed)
        let phase2 = ((t + 0.7).truncatingRemainder(dividingBy: 2.2 / speed)) / (2.2 / speed)
        Group {
            ring(color: Color(hex: 0xD98D7A).opacity(0.4), phase: phase1)
            ring(color: Color(hex: 0xB87294).opacity(0.35), phase: phase2)
        }
    }

    @ViewBuilder
    func ring(color: Color, phase: Double) -> some View {
        Circle()
            .strokeBorder(color, lineWidth: 1.5)
            .frame(width: size, height: size)
            .scaleEffect(CGFloat(1 + phase * 0.4))
            .opacity(1 - phase)
    }

    var groundShadow: some View {
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

    var mainSphere: some View {
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
    var conicAura: some View {
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
    var auraColors: [Color] {
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
    func innerRing(phase: Double) -> some View {
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

    var topSpecular: some View {
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

    var tightHotSpot: some View {
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
    var rimOcclusion: some View {
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
    var baseOcclusion: some View {
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

    var lowerRefractionGlow: some View {
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

    var rimLight: some View {
        // No stroked rim — the discrete arc was reading as a hard
        // unblended line on top of the sphere. The specular highlight
        // and hot spot already carry all the volume we need, and the
        // outer shadow + halo handle the edge softening.
        EmptyView()
    }

    // MARK: - Face

    @ViewBuilder
    var faceEyes: some View {
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
    func eye(color: Color, sparkle: Color) -> some View {
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
    var smileAmount: Double {
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
    func thinkingDots(t: TimeInterval) -> some View {
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
