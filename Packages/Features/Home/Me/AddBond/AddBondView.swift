import ComposableArchitecture
import SwiftUI

// MARK: - Add Bond View
//
// Root container for the AddBond flow. Owns the full-screen
// background (same cycle-phase watercolour treatment as the Me cards
// so the destination feels like a continuation of where the user
// tapped) and switches on `store.step` to render the current screen
// with an asymmetric slide+fade transition.

public struct AddBondView: View {
    @Bindable var store: StoreOf<AddBondFeature>
    let onDismiss: () -> Void

    public init(store: StoreOf<AddBondFeature>, onDismiss: @escaping () -> Void) {
        self.store = store
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            backgroundLayer
                .ignoresSafeArea()

            Group {
                switch store.step {
                case .intro:
                    AddBondIntroView(store: store, onDismiss: onDismiss)
                        .transition(stepTransition)

                case .name:
                    AddBondNameView(store: store, onDismiss: onDismiss)
                        .transition(stepTransition)

                case .birthDate:
                    AddBondBirthDateView(store: store, onDismiss: onDismiss)
                        .transition(stepTransition)

                case .birthTime:
                    AddBondBirthTimeView(store: store, onDismiss: onDismiss)
                        .transition(stepTransition)

                case .birthPlace:
                    AddBondBirthPlaceView(store: store, onDismiss: onDismiss)
                        .transition(stepTransition)

                case .generating:
                    AddBondGeneratingView(store: store, onDismiss: onDismiss)
                        .transition(stepTransition)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.86), value: store.step)

            // Persistent back — sits above every step *except* the
            // generating loading screen, where the flow is
            // intentionally non-interruptible. On intro the back
            // tears the flow down via `onDismiss`; on every other
            // step the reducer's `.backTapped` walks the step
            // machine back one screen and the transition reverses.
            //
            // Uses an inline `nativeGlass(.., interactive: true)`
            // button rather than the static `GlassBackButton` so
            // iOS 26+ picks up Apple's `.glassEffect(.interactive)`
            // — the disc visibly deforms / "bubbles" while held —
            // and iOS 17–25 still gets the same `.ultraThinMaterial`
            // + rim fallback. Same 44pt footprint as the close X
            // on BondReading so back and close read as a pair.
            if store.step != .generating {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    if store.step == .intro {
                        onDismiss()
                    } else {
                        store.send(.backTapped)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignColors.text)
                        .frame(width: 44, height: 44)
                        .nativeGlass(in: Circle(), interactive: true)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .padding(.leading, AppLayout.horizontalPadding)
                .padding(.top, 16)
                .zIndex(10)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Transition

    /// Direction-aware slide: forward steps come in from the trailing
    /// edge and leave toward the leading edge; backward steps swap
    /// both endpoints so the gesture reads as "going back" rather
    /// than "another forward push". `store.lastNavigation` is set
    /// inside the reducer before the step mutation in the same
    /// action so the transition picks up the right value at the
    /// instant SwiftUI computes insertion/removal.
    private var stepTransition: AnyTransition {
        switch store.lastNavigation {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    // MARK: - Background

    /// Same warm peach `AppleHealthBackground` used across the rest
    /// of the app (Me, Calendar, CycleInsights, BodyPatterns) so the
    /// flow reads as a continuation of the same surface rather than
    /// a foreign sheet.
    private var backgroundLayer: some View {
        AppleHealthBackground()
    }

}

#Preview {
    AddBondView(
        store: .init(initialState: AddBondFeature.State()) {
            AddBondFeature()
        },
        onDismiss: {}
    )
}
