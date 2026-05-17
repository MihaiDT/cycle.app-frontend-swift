import ComposableArchitecture
import SwiftUI

// MARK: - Add Bond — Name Step
//
// Second screen of the AddBond flow. The hero now reads as a single
// "other" blob waiting to be named — the bond pair from the intro
// has separated, and the screen is asking the user who this person
// is. A centred glass text field collects the name. A "Prefer not to
// say" checkbox lets privacy-conscious users continue anonymously;
// when ticked, the text field is greyed out and the Continue button
// activates without a name. The persistent back button in
// AddBondView's chrome handles dismissal — no inline back/skip here.

struct AddBondNameView: View {
    @Bindable var store: StoreOf<AddBondFeature>
    let onDismiss: () -> Void

    @FocusState private var isNameFocused: Bool

    // Staggered entrance — same cadence as AddBondIntroView so the
    // flow has a single visual heartbeat.
    @State private var watermarkIn = false
    @State private var blobIn = false
    @State private var eyebrowIn = false
    @State private var titleIn = false
    @State private var bodyIn = false
    @State private var fieldIn = false
    @State private var checkboxIn = false
    @State private var buttonIn = false

    private var trimmedName: String {
        store.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        store.isAnonymous || !trimmedName.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Same 72pt top inset as the intro so the persistent back
            // button never overlaps the hero on smaller devices.
            Spacer(minLength: 72)

            heroBlock

            Spacer(minLength: 18)

            textBlock

            Spacer(minLength: 26)

            nameField

            anonymousCheckbox
                .padding(.top, 18)

            Spacer(minLength: 0)

            continueButton
                .padding(.bottom, 24)
        }
        .padding(.horizontal, AppLayout.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: animateIn)
    }

    // MARK: - Hero (single blob inside the venn watermark)

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

            // The "other" blob alone — the empty side of the pair,
            // sitting where the name we're about to type will live.
            Image("BondBlobEmpty")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 132, height: 132)
                .rotationEffect(.degrees(140))
                .breathing(enabled: true)
                .scaleEffect(blobIn ? 1.0 : 0.86)
                .opacity(blobIn ? 1 : 0)
        }
        .frame(height: 180)
    }

    // MARK: - Text (eyebrow + title + body)

    private var textBlock: some View {
        VStack(spacing: 0) {
            Text("Their name")
                .font(.raleway("SemiBold", size: 12, relativeTo: .caption2))
                .tracking(1.4)
                .foregroundStyle(DesignColors.textSecondary)
                .textCase(.uppercase)
                .opacity(eyebrowIn ? 1 : 0)
                .offset(y: eyebrowIn ? 0 : 10)

            Text("What should\nwe call them?")
                .font(.raleway("Bold", size: 30, relativeTo: .title))
                .tracking(-0.5)
                .foregroundStyle(DesignColors.textPrincipal)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 12)
                .opacity(titleIn ? 1 : 0)
                .offset(y: titleIn ? 0 : 12)

            Text("A name we'll use throughout the app. Stay anonymous if you'd rather.")
                .font(.raleway("Medium", size: 15, relativeTo: .body))
                .tracking(0.1)
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
                .padding(.horizontal, 4)
                .opacity(bodyIn ? 1 : 0)
                .offset(y: bodyIn ? 0 : 10)
        }
    }

    // MARK: - Name field

    private var nameField: some View {
        GlassTextField(
            text: $store.name,
            placeholder: "Their name"
        )
        .focused($isNameFocused)
        .submitLabel(.done)
        .onSubmit {
            if canContinue {
                store.send(.nameContinueTapped)
            }
        }
        .disabled(store.isAnonymous)
        .opacity(fieldIn ? (store.isAnonymous ? 0.45 : 1.0) : 0)
        .offset(y: fieldIn ? 0 : 12)
        .animation(.easeOut(duration: 0.25), value: store.isAnonymous)
    }

    // MARK: - Anonymous opt-out
    //
    // Custom compact row instead of `GlassCheckbox` — that component
    // wraps its icon in a 44pt hit frame and pushes the label with a
    // 16pt spacing, which left a too-wide visual gap between the
    // radio and the text. Here the icon sits 10pt from the label and
    // the whole row is centred under the text field, so it reads as
    // a paired unit rather than a left-aligned form row.

    private var anonymousCheckbox: some View {
        Button {
            store.isAnonymous.toggle()
            if store.isAnonymous {
                isNameFocused = false
            }
        } label: {
            HStack(spacing: 12) {
                BondSelectionCheckbox(isSelected: store.isAnonymous)
                    .frame(width: 24, height: 24)

                Text("Prefer not to say")
                    .font(.raleway("Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.textPrincipal)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityAddTraits(
            store.isAnonymous ? [.isButton, .isSelected] : .isButton
        )
        .opacity(checkboxIn ? 1 : 0)
        .offset(y: checkboxIn ? 0 : 10)
    }

    // MARK: - CTA

    private var continueButton: some View {
        // Same two-layer cross-fade pattern as BirthPlace: a
        // dimmed warm capsule made the white label unreadable, so
        // disabled state gets its own muted stand-in (dusty-rose
        // wash + soft charcoal text) and the two stack with
        // opacities cross-fading on `canContinue`.
        ZStack {
            WarmCapsuleButton(
                "Continue",
                prominence: .primary,
                isFullWidth: false
            ) {
                isNameFocused = false
                store.send(.nameContinueTapped)
            }
            .opacity(canContinue ? 1 : 0)

            disabledContinueButton
                .opacity(canContinue ? 0 : 1)
                .allowsHitTesting(false)
        }
        .opacity(buttonIn ? 1 : 0)
        .scaleEffect(buttonIn ? 1.0 : 0.94)
        .animation(.easeOut(duration: 0.25), value: canContinue)
    }

    private var disabledContinueButton: some View {
        Text("Continue")
            .font(.raleway("SemiBold", size: 15, relativeTo: .body))
            .foregroundStyle(DesignColors.textSecondary)
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(DesignColors.accentSecondary.opacity(0.22))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                DesignColors.accentSecondary.opacity(0.35),
                                lineWidth: 0.6
                            )
                    )
            )
    }

    // MARK: - Entrance animation

    private func animateIn() {
        withAnimation(.easeOut(duration: 1.0)) {
            watermarkIn = true
        }
        withAnimation(.spring(response: 0.85, dampingFraction: 0.82).delay(0.15)) {
            blobIn = true
        }
        withAnimation(.easeOut(duration: 0.65).delay(0.38)) {
            eyebrowIn = true
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.5)) {
            titleIn = true
        }
        withAnimation(.easeOut(duration: 0.65).delay(0.64)) {
            bodyIn = true
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.78)) {
            fieldIn = true
        }
        withAnimation(.easeOut(duration: 0.55).delay(0.88)) {
            checkboxIn = true
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.98)) {
            buttonIn = true
        }
    }
}

// MARK: - Bond Selection Checkbox (Onboarding Style)
//
// Mirrors the onboarding `SelectionCheckbox` exactly — same shapes,
// same stroke style, same accentWarm checkmark colour. Inlined here
// because both the DesignSystem `GlassCheckbox` icon and onboarding's
// version keep their shapes file-private; copying is cheaper than
// hoisting a public type just for this one consent-style toggle.

private struct BondSelectionCheckbox: View {
    let isSelected: Bool

    private var checkmarkColor: Color { DesignColors.accentWarm }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: 1.78125 * (24.0 / 19.0),
            lineCap: .round,
            lineJoin: .round
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignColors.accentSecondary.opacity(0.5), style: strokeStyle)
                .opacity(isSelected ? 0 : 1)

            BondCheckboxCircleWithGap()
                .stroke(checkmarkColor, style: strokeStyle)
                .opacity(isSelected ? 1 : 0)

            BondCheckboxCheckmark(progress: isSelected ? 1 : 0)
                .stroke(checkmarkColor, style: strokeStyle)
                .animation(.easeOut(duration: 0.2), value: isSelected)
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

private struct BondCheckboxCircleWithGap: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 19.0
        var path = Path()

        path.move(to: CGPoint(x: 17.4168 * scale, y: 8.77148 * scale))
        path.addLine(to: CGPoint(x: 17.4168 * scale, y: 9.49981 * scale))

        path.addCurve(
            to: CGPoint(x: 15.8409 * scale, y: 14.2354 * scale),
            control1: CGPoint(x: 17.4159 * scale, y: 11.207 * scale),
            control2: CGPoint(x: 16.8631 * scale, y: 12.8681 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 11.7448 * scale, y: 17.0871 * scale),
            control1: CGPoint(x: 14.8187 * scale, y: 15.6027 * scale),
            control2: CGPoint(x: 13.3819 * scale, y: 16.603 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 6.75662 * scale, y: 16.9214 * scale),
            control1: CGPoint(x: 10.1077 * scale, y: 17.5711 * scale),
            control2: CGPoint(x: 8.35799 * scale, y: 17.513 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 2.85884 * scale, y: 13.8042 * scale),
            control1: CGPoint(x: 5.15524 * scale, y: 16.3297 * scale),
            control2: CGPoint(x: 3.78801 * scale, y: 15.2363 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 1.60066 * scale, y: 8.97439 * scale),
            control1: CGPoint(x: 1.92967 * scale, y: 12.372 * scale),
            control2: CGPoint(x: 1.48833 * scale, y: 10.6779 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 3.48213 * scale, y: 4.35166 * scale),
            control1: CGPoint(x: 1.71298 * scale, y: 7.27093 * scale),
            control2: CGPoint(x: 2.37295 * scale, y: 5.6494 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 7.75548 * scale, y: 1.77326 * scale),
            control1: CGPoint(x: 4.59132 * scale, y: 3.05392 * scale),
            control2: CGPoint(x: 6.09028 * scale, y: 2.14949 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 12.7223 * scale, y: 2.26398 * scale),
            control1: CGPoint(x: 9.42067 * scale, y: 1.39703 * scale),
            control2: CGPoint(x: 11.1629 * scale, y: 1.56916 * scale)
        )

        return path
    }
}

private struct BondCheckboxCheckmark: Shape {
    var animatableData: CGFloat

    init(progress: CGFloat = 1) {
        self.animatableData = progress
    }

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 19.0
        var path = Path()
        path.move(to: CGPoint(x: 7.12517 * scale, y: 8.71606 * scale))
        path.addLine(to: CGPoint(x: 9.50017 * scale, y: 11.0911 * scale))
        path.addLine(to: CGPoint(x: 17.4168 * scale, y: 3.16648 * scale))
        return path.trimmedPath(from: 0, to: animatableData)
    }
}

// MARK: - Subtle breathing modifier (mirrors BondBlobPair's animation)

private struct BreathingModifier: ViewModifier {
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
    func breathing(enabled: Bool) -> some View {
        modifier(BreathingModifier(enabled: enabled))
    }
}

#Preview {
    AddBondView(
        store: .init(initialState: AddBondFeature.State(step: .name)) {
            AddBondFeature()
        },
        onDismiss: {}
    )
}
