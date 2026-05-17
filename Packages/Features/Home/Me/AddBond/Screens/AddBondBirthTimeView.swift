import ComposableArchitecture
import SwiftUI

// MARK: - Add Bond — Birth Time Step
//
// Fourth screen of the AddBond flow. Same editorial shell as the
// preceding steps (Venn watermark + single blob hero, eyebrow,
// title, body). The picker is a custom two-column scroll wheel —
// hours on the left, minutes on the right — with strong scale and
// opacity falloff from centre, producing the "hourglass" silhouette
// from the reference image. The native `DatePicker(.wheel)` reads as
// too utilitarian against this editorial flow; the custom column
// gives a softer, slower-feeling selector while staying tactile.

struct AddBondBirthTimeView: View {
    @Bindable var store: StoreOf<AddBondFeature>
    let onDismiss: () -> Void

    // Picker-local state. Initialised from `store.birthTime` on
    // appear; commits back via `commitTime()` whenever either column
    // changes so the reducer's `birthTime` stays in sync.
    @State private var hour: Int = 12
    @State private var minute: Int = 0

    // Staggered entrance.
    @State private var watermarkIn = false
    @State private var blobIn = false
    @State private var eyebrowIn = false
    @State private var titleIn = false
    @State private var bodyIn = false
    @State private var pickerIn = false
    @State private var buttonIn = false

    private var formattedTime: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 72)

            heroBlock

            Spacer(minLength: 14)

            textBlock

            Spacer(minLength: 18)

            picker

            Spacer(minLength: 0)

            continueButton
                .padding(.bottom, 24)
        }
        .padding(.horizontal, AppLayout.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            let comps = Calendar.current.dateComponents(
                [.hour, .minute], from: store.birthTime
            )
            hour = comps.hour ?? 12
            minute = comps.minute ?? 0
            animateIn()
        }
        .onChange(of: hour) { _, _ in commitTime() }
        .onChange(of: minute) { _, _ in commitTime() }
    }

    // MARK: - Hero

    private var heroBlock: some View {
        ZStack {
            VennCirclesWatermark(
                strokeColor: DesignColors.accentWarm,
                lineWidth: 1.6,
                opacity: 0.14,
                circleSize: 180,
                overlap: 74
            )
            .scaleEffect(watermarkIn ? 1.0 : 0.94)
            .opacity(watermarkIn ? 1 : 0)

            Image("BondBlobEmpty")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 132, height: 132)
                .rotationEffect(.degrees(140))
                .birthTimeBreathing(enabled: true)
                .scaleEffect(blobIn ? 1.0 : 0.86)
                .opacity(blobIn ? 1 : 0)
        }
        .frame(height: 180)
    }

    // MARK: - Text

    private var textBlock: some View {
        VStack(spacing: 0) {
            Text("Their birth time")
                .font(.raleway("SemiBold", size: 12, relativeTo: .caption2))
                .tracking(1.4)
                .foregroundStyle(DesignColors.textSecondary)
                .textCase(.uppercase)
                .opacity(eyebrowIn ? 1 : 0)
                .offset(y: eyebrowIn ? 0 : 10)

            Text("What hour\ndid they arrive?")
                .font(.raleway("Bold", size: 28, relativeTo: .title))
                .tracking(-0.5)
                .foregroundStyle(DesignColors.textPrincipal)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 10)
                .opacity(titleIn ? 1 : 0)
                .offset(y: titleIn ? 0 : 12)

            Text("Roll to set the hour. Even an approximate time helps.")
                .font(.raleway("Medium", size: 14, relativeTo: .body))
                .tracking(0.1)
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .padding(.horizontal, 4)
                .opacity(bodyIn ? 1 : 0)
                .offset(y: bodyIn ? 0 : 10)
        }
    }

    // MARK: - Picker

    private var picker: some View {
        // Columns are intrinsic-greedy (ScrollView fills any width
        // it's given), so each is pinned to a fixed width and the
        // HStack is centred. Result: hours and minutes hug a thin
        // central colon instead of being pushed to the screen edges.
        HStack(spacing: 4) {
            BondTimeWheelColumn(
                values: Array(0...23),
                selected: $hour
            )
            .frame(width: 90)

            Text(":")
                .font(.raleway("Light", size: 38))
                .foregroundStyle(DesignColors.textPrincipal.opacity(0.35))
                .padding(.bottom, 4)

            BondTimeWheelColumn(
                values: Array(0...59),
                selected: $minute
            )
            .frame(width: 90)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .opacity(pickerIn ? 1 : 0)
        .offset(y: pickerIn ? 0 : 14)
    }

    // MARK: - CTA

    private var continueButton: some View {
        WarmCapsuleButton(
            "Continue",
            prominence: .primary,
            isFullWidth: false
        ) {
            store.send(.birthTimeContinueTapped)
        }
        .opacity(buttonIn ? 1 : 0)
        .scaleEffect(buttonIn ? 1.0 : 0.94)
    }

    // MARK: - Behaviour

    private func commitTime() {
        let cal = Calendar.current
        guard
            let newDate = cal.date(
                bySettingHour: hour, minute: minute, second: 0, of: store.birthTime
            )
        else { return }
        store.birthTime = newDate
    }

    private func animateIn() {
        withAnimation(.easeOut(duration: 1.0)) { watermarkIn = true }
        withAnimation(.spring(response: 0.85, dampingFraction: 0.82).delay(0.15)) {
            blobIn = true
        }
        withAnimation(.easeOut(duration: 0.65).delay(0.32)) { eyebrowIn = true }
        withAnimation(.easeOut(duration: 0.7).delay(0.44)) { titleIn = true }
        withAnimation(.easeOut(duration: 0.65).delay(0.56)) { bodyIn = true }
        withAnimation(.easeOut(duration: 0.7).delay(0.7)) { pickerIn = true }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.92)) {
            buttonIn = true
        }
    }
}

// MARK: - Bond Time Wheel Column
//
// Vertical scroll list of zero-padded integers. The centred row is
// the selected value; scale + opacity + blur fall off symmetrically
// above and below using `scrollTransition`. `contentMargins(.vertical, ..., for: .scrollContent)`
// lets the first/last items snap to the centre line (otherwise the
// shortest reach would be capped at edge anchoring).

private struct BondTimeWheelColumn: View {
    let values: [Int]
    @Binding var selected: Int

    // Single row height drives both row layout and the surrounding
    // 5-row visible window (2 above, centre, 2 below).
    private let rowHeight: CGFloat = 44
    private var visibleRows: Int { 5 }
    private var visibleHeight: CGFloat { CGFloat(visibleRows) * rowHeight }
    private var sideMargin: CGFloat {
        (visibleHeight - rowHeight) / 2
    }

    // Binding adapter — `scrollPosition(id:)` wants `Binding<Int?>`.
    private var positionBinding: Binding<Int?> {
        Binding(
            get: { selected },
            set: { newValue in
                if let v = newValue, v != selected { selected = v }
            }
        )
    }

    var body: some View {
        ZStack {
            // Liquid-glass capsule behind the centre row — the
            // selected value visually rests on glass while the
            // rest of the wheel scrolls past it. `nativeGlass`
            // picks up iOS 26's `.glassEffect` for real Liquid
            // Glass, and falls back to `.ultraThinMaterial` + rim
            // on iOS 17–25. Sits at the ZStack's centre, behind
            // the scroll content, so it isn't masked by the
            // wheel's edge fade.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: rowHeight)
                .nativeGlass(in: Capsule(), interactive: false)
                .allowsHitTesting(false)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(values, id: \.self) { value in
                        Text(String(format: "%02d", value))
                            .font(.system(size: 40, weight: .regular, design: .default))
                            .foregroundStyle(DesignColors.textPrincipal)
                            .frame(height: rowHeight)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .scrollTransition(.interactive, axis: .vertical) { content, phase in
                                let d = min(abs(phase.value), 2.0)
                                return content
                                    .opacity(1 - d * 0.36)
                                    .scaleEffect(1 - d * 0.34)
                                    .blur(radius: d * 0.6)
                            }
                            .id(value)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.vertical, sideMargin, for: .scrollContent)
            .scrollPosition(id: positionBinding, anchor: .center)
            // Native picker tick — fires as each value snaps under
            // the centre anchor while the user is scrolling.
            .sensoryFeedback(.selection, trigger: selected)
            .mask(
                // Soft top/bottom fade so the edges don't read as hard
                // cuts — supports the converging hourglass feel.
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.28),
                        .init(color: .black, location: 0.72),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(height: visibleHeight)
    }
}

// MARK: - Subtle breathing modifier (file-local copy)

private struct BirthTimeBreathingModifier: ViewModifier {
    let enabled: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 + (enabled ? phase : 0))
            .onAppear {
                guard enabled else { return }
                withAnimation(
                    .easeInOut(duration: 3.4).repeatForever(autoreverses: true)
                ) {
                    phase = 0.015
                }
            }
    }
}

private extension View {
    func birthTimeBreathing(enabled: Bool) -> some View {
        modifier(BirthTimeBreathingModifier(enabled: enabled))
    }
}

#Preview {
    AddBondView(
        store: .init(initialState: AddBondFeature.State(step: .birthTime)) {
            AddBondFeature()
        },
        onDismiss: {}
    )
}
