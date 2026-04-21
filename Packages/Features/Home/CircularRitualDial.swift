import SwiftUI

// MARK: - Circular Ritual Dial
//
// Sphere anchored to the left (half-visible), vertically centered.
// The 5 mood words fan out on a semicircular arc around the sphere's
// right edge — active word at 3 o'clock (bold italic, staggered reveal),
// neighbors above and below on the arc. Tap any word to select it; a
// vertical drag anywhere on the stage cycles through them. All five
// states are always visible and individually addressable.

struct CircularRitualDial: View {
    let words: [String]
    @Binding var index: Int

    // 5 sphere palettes — darkest (heavy / drained) → lightest (luminous / electric).
    // Applied to the RadialGradient based on current index so the sphere
    // breathes with the chosen word.
    private let spherePalettes: [(Color, Color, Color)] = [
        (Color(red: 0xD4/255, green: 0xA5/255, blue: 0x9D/255),
         Color(red: 0xBF/255, green: 0x85/255, blue: 0x7D/255),
         Color(red: 0x8C/255, green: 0x5C/255, blue: 0x55/255)),
        (Color(red: 0xEC/255, green: 0xC0/255, blue: 0xB4/255),
         Color(red: 0xDB/255, green: 0xA0/255, blue: 0x95/255),
         Color(red: 0xB0/255, green: 0x80/255, blue: 0x76/255)),
        (Color(red: 0xFC/255, green: 0xE6/255, blue: 0xD4/255),
         Color(red: 0xF3/255, green: 0xC9/255, blue: 0xC2/255),
         Color(red: 0xC9/255, green: 0x9B/255, blue: 0x95/255)),
        (Color(red: 0xFE/255, green: 0xEE/255, blue: 0xDC/255),
         Color(red: 0xFA/255, green: 0xD0/255, blue: 0xBF/255),
         Color(red: 0xE0/255, green: 0xA6/255, blue: 0x9A/255)),
        (Color(red: 0xFF/255, green: 0xF5/255, blue: 0xE7/255),
         Color(red: 0xFC/255, green: 0xDC/255, blue: 0xC7/255),
         Color(red: 0xF0/255, green: 0xB8/255, blue: 0xA3/255))
    ]

    private let stepHeight: CGFloat = 68

    @State private var dragStartIndex: Int = 2
    @State private var isDragging: Bool = false
    @State private var didAppear: Bool = false
    @State private var didInteract: Bool = false
    @State private var spherePulse: Bool = false
    /// Continuous tracker that follows the finger while dragging so the
    /// active word's scale and opacity glide between slots — gives the
    /// scroll that analog-picker feel before snapping on release.
    @State private var fractionalIndex: Double = 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let haptic = UIImpactFeedbackGenerator(style: .soft)
    private let settleHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionHaptic = UISelectionFeedbackGenerator()

    var body: some View {
        GeometryReader { proxy in
            let stageH = min(proxy.size.height, 460)
            let dia = min(320, proxy.size.width * 0.82)
            // Elliptical arc — horizontal radius keeps the active pill
            // clear of the sphere + its shadow; vertical radius gives
            // enough gap that the 5 glass pills never touch, even when
            // the active one scales up to 1.30×.
            let xRadius = dia / 2 + 130
            let yRadius = dia / 2 + 18

            ZStack(alignment: .leading) {
                sphere(diameter: dia)
                    .offset(x: didAppear ? -dia / 2 : -(dia * 1.15))
                    .opacity(didAppear ? 1 : 0)
                    .scaleEffect(spherePulse ? 1.04 : 1.0)
                    .animation(
                        reduceMotion
                            ? nil
                            : .spring(response: 0.75, dampingFraction: 0.85),
                        value: didAppear
                    )
                    .animation(.spring(response: 0.35, dampingFraction: 0.55), value: spherePulse)
                    .onTapGesture {
                        haptic.impactOccurred()
                        spherePulse = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            spherePulse = false
                        }
                    }

                ForEach(0..<5, id: \.self) { i in
                    arcWord(i: i)
                        .position(
                            x: xRadius * CGFloat(cos(arcAngleRad(for: i))),
                            y: stageH / 2 + yRadius * CGFloat(sin(arcAngleRad(for: i)))
                        )
                        .scaleEffect(didAppear ? 1 : 0.72)
                        .opacity(didAppear ? 1 : 0)
                        .animation(
                            reduceMotion
                                ? nil
                                : .spring(response: 0.5, dampingFraction: 0.85),
                            value: index
                        )
                        .animation(
                            reduceMotion
                                ? nil
                                : .spring(response: 0.42, dampingFraction: 0.78)
                                    .delay(0.72 + Double(abs(i - 2)) * 0.18),
                            value: didAppear
                        )
                }
            }
            .frame(width: proxy.size.width, height: stageH, alignment: .center)
            .contentShape(Rectangle())
            .gesture(verticalDrag)
        }
        .frame(height: 460)
        .onAppear {
            haptic.prepare()
            selectionHaptic.prepare()
            fractionalIndex = Double(index)
            didAppear = true

            // Heavy thud as the sphere settles in from the left — timed
            // to the tail of its slide-in spring (response ≈ 0.75s).
            // Then three soft taps as the pills cascade out from the
            // centre (slot 0) → neighbours (±1) → edges (±2).
            if !reduceMotion {
                let arrivalHaptic = UIImpactFeedbackGenerator(style: .heavy)
                arrivalHaptic.prepare()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    arrivalHaptic.impactOccurred(intensity: 1.0)
                }

                let pillHaptic = UIImpactFeedbackGenerator(style: .soft)
                pillHaptic.prepare()
                for wave in 0...2 {
                    let fireAt = 0.72 + Double(wave) * 0.18
                    DispatchQueue.main.asyncAfter(deadline: .now() + fireAt) {
                        pillHaptic.impactOccurred(intensity: 0.75)
                        pillHaptic.prepare()
                    }
                }
            }
        }
        .onChange(of: index) { _, newValue in
            guard !isDragging else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                fractionalIndex = Double(newValue)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mood picker")
        .accessibilityValue(words[index])
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if index < 4 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        index += 1
                    }
                    selectionHaptic.selectionChanged()
                }
            case .decrement:
                if index > 0 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        index -= 1
                    }
                    selectionHaptic.selectionChanged()
                }
            @unknown default: break
            }
        }
    }

    // MARK: - Arc geometry

    /// Angular span (degrees) between two adjacent slots on the arc.
    /// Slots are fixed: word 0 at -48°, word 4 at +48°. The active
    /// indicator is a typography/colour change on whichever word
    /// matches `index` — the arc itself does not rotate, so no word
    /// ever wraps off-screen at the index extremes.
    private let arcSpreadDeg: Double = 24

    /// Radians at which word `i` sits on the arc — purely positional,
    /// independent of the active index.
    private func arcAngleRad(for i: Int) -> Double {
        Double(i - 2) * arcSpreadDeg * .pi / 180.0
    }

    /// Opacity falloff keyed on fractional distance from the active
    /// tracker. Steeper curve — since active/inactive share font weight
    /// and colour, opacity must carry the emphasis on its own.
    private func smoothOpacity(for i: Int) -> Double {
        let d = abs(Double(i) - fractionalIndex)
        switch d {
        case ..<1: return 1.0 - d * 0.55
        case ..<2: return 0.45 - (d - 1) * 0.20
        case ..<3: return 0.25 - (d - 2) * 0.08
        default:   return 0.18
        }
    }

    // MARK: - Contrast-adaptive text colour
    //
    // At low indices the reactive background is in its darker tones
    // (mauve / tan / earth brown) — dark accent text becomes hard to
    // read. Swap to a warm cream for contrast; use the app's accent
    // text colour on lighter backgrounds. A single colour across all
    // words — active/inactive distinction is carried by opacity alone,
    // so nothing jumps when the selection crosses a step.

    private var useLightText: Bool { index <= 1 }

    private var wordColor: Color {
        useLightText ? Color(hex: 0xFFF5E8) : DesignColors.accentWarmText
    }

    // MARK: - Arc word

    /// How close word `i` is to being the selected one — 1 on centre,
    /// 0 a full slot away. Drives the highlight pill's fade so it
    /// glides smoothly between words during drag.
    private func activeness(for i: Int) -> Double {
        max(0, 1 - abs(Double(i) - fractionalIndex))
    }

    @ViewBuilder
    private func arcWord(i: Int) -> some View {
        let isActive = i == index
        let a = activeness(for: i)

        Text(words[i])
            .font(.raleway("SemiBold", size: 22, relativeTo: .body))
            .italic()
            .foregroundStyle(wordColor)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Color.white.opacity(a * 0.55))
                    .shadow(
                        color: .black.opacity(a * 0.08),
                        radius: 4, x: 0, y: 1
                    )
            )
            .opacity(smoothOpacity(for: i))
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isDragging else { return }
                if !didInteract { didInteract = true }
                selectionHaptic.selectionChanged()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    index = i
                    fractionalIndex = Double(i)
                }
            }
            .accessibilityLabel(
                isActive
                    ? "\(words[i]), selected. Option \(i + 1) of 5"
                    : "\(words[i]), option \(i + 1) of 5"
            )
            .accessibilityAddTraits(isActive ? .isSelected : .isButton)
            .accessibilityHint(isActive ? "" : "Double tap to select")
    }

    // MARK: - Sphere

    private func sphere(diameter dia: CGFloat) -> some View {
        let palette = spherePalettes[max(0, min(4, index))]
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.0, palette.1, palette.2],
                        center: UnitPoint(x: 0.32, y: 0.28),
                        startRadius: 10,
                        endRadius: dia * 0.62
                    )
                )
                .animation(.easeInOut(duration: 0.55), value: index)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.32), Color.white.opacity(0)],
                        center: UnitPoint(x: 0.28, y: 0.22),
                        startRadius: 4,
                        endRadius: dia * 0.36
                    )
                )

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.6), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .frame(width: dia, height: dia)
        .shadow(color: DesignColors.accentWarm.opacity(0.32), radius: 32, x: 0, y: 14)
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Drag

    private var verticalDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartIndex = index
                    haptic.prepare()
                    selectionHaptic.prepare()
                    if !didInteract { didInteract = true }
                }
                // Drag down → selects word lower on the arc (higher
                // index); drag up → selects word higher on the arc.
                let raw = Double(dragStartIndex) + Double(value.translation.height) / Double(stepHeight)
                // Tight rubber band at the ends — resists overscroll
                // without feeling floaty.
                let clamped = rubberBand(raw, min: 0, max: 4)
                fractionalIndex = clamped

                let snapped = max(0, min(4, Int(clamped.rounded())))
                if snapped != index {
                    index = snapped
                    selectionHaptic.selectionChanged()
                    selectionHaptic.prepare()
                }
            }
            .onEnded { _ in
                // Snap exactly to the word closest to the finger's final
                // position — no momentum flick, so the result always
                // matches where the user released.
                let targetIdx = max(0, min(4, Int(fractionalIndex.rounded())))

                if targetIdx != index {
                    index = targetIdx
                    selectionHaptic.selectionChanged()
                }

                withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                    fractionalIndex = Double(targetIdx)
                }
                isDragging = false
                settleHaptic.impactOccurred(intensity: 0.6)
            }
    }

    /// Soft resistance past the clamp bounds — scaled tight (0.18) so
    /// the end stops feel firm, not elastic.
    private func rubberBand(_ value: Double, min lo: Double, max hi: Double) -> Double {
        if value < lo { return lo - (lo - value) * 0.18 }
        if value > hi { return hi + (value - hi) * 0.18 }
        return value
    }
}

// MARK: - Staggered center word
//
// Progressive-reveal: letters start hidden (opacity 0, offset 16)
// and are revealed one at a time by incrementing `visibleCount`.
// Each letter uses a spring transition keyed on its own visibility,
// so on appear the word cascades from invisible → visible without
// the "word flashes full first, then animates" artefact.

private struct StaggeredCenterWord: View {
    let text: String
    let fontSize: CGFloat
    let color: Color
    let reduceMotion: Bool
    let isScrolling: Bool

    @State private var visibleCount: Int = 0

    /// Font tapers smoothly for longer words so 8-9 letter words
    /// (luminous, gathering, electric) don't overflow the picker width.
    private var adaptiveFontSize: CGFloat {
        let n = text.count
        switch n {
        case 0...5:  return fontSize              // heavy / muted / low
        case 6:      return fontSize * 0.94
        case 7:      return fontSize * 0.82
        case 8:      return fontSize * 0.72
        default:     return fontSize * 0.64       // 9+: gathering
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { i, ch in
                Text(String(ch))
                    .font(.raleway("Bold", size: adaptiveFontSize, relativeTo: .largeTitle))
                    .italic()
                    .foregroundStyle(color)
                    .offset(y: i < visibleCount ? 0 : 16)
                    .opacity(i < visibleCount ? 1 : 0)
                    .animation(
                        reduceMotion
                            ? nil
                            : .spring(response: 0.5, dampingFraction: 0.78),
                        value: visibleCount
                    )
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .onAppear {
            if isScrolling || reduceMotion {
                snapFullyVisible()
            } else {
                startCascade()
            }
        }
        .onChange(of: text) { _, newValue in
            if isScrolling {
                // Mid-scroll text swap — keep letters visible, no cascade.
                snapFullyVisible(count: newValue.count)
            } else if !reduceMotion {
                // Text changed while idle (e.g. user tapped a neighbor) —
                // run the cascade on the new word.
                startCascade()
            }
        }
        .onChange(of: isScrolling) { _, newValue in
            if !newValue && !reduceMotion {
                // Drag just ended → trigger the cascade on the committed word.
                startCascade()
            }
        }
    }

    private func snapFullyVisible(count: Int? = nil) {
        var t = Transaction(animation: nil)
        t.disablesAnimations = true
        withTransaction(t) {
            visibleCount = count ?? text.count
        }
    }

    private func startCascade() {
        if reduceMotion {
            snapFullyVisible()
            return
        }
        // Reset instantly without animation, then stagger letters in.
        var t = Transaction(animation: nil)
        t.disablesAnimations = true
        withTransaction(t) { visibleCount = 0 }

        for i in 0..<text.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.04) {
                visibleCount = i + 1
            }
        }
    }
}
