import ComposableArchitecture
import SwiftUI

// MARK: - Add Bond — Birth Place Step
//
// Final screen of the AddBond flow. Same editorial shell as the
// preceding four steps. Uses the onboarding `PlacesAutocompleteTextField`
// wired to the real `PlacesClient` (Google Places proxied through
// the dth-backend) — identical search/select closures as the
// onboarding `BirthDataView` so this screen behaves the same as the
// onboarding birth-place field. The selected `SelectedPlace` is
// bridged into the reducer's `birthPlace: BondBirthPlace?`. The CTA
// reads "Save" and is disabled until a place is selected; tapping
// it builds the `Bond` and dismisses the flow via the reducer's
// `birthPlaceContinueTapped` action.

struct AddBondBirthPlaceView: View {
    @Bindable var store: StoreOf<AddBondFeature>
    let onDismiss: () -> Void

    @State private var searchText: String = ""
    @State private var selectedPlace: PlacesAutocompleteTextField.SelectedPlace?

    @State private var watermarkIn = false
    @State private var blobIn = false
    @State private var eyebrowIn = false
    @State private var titleIn = false
    @State private var bodyIn = false
    @State private var fieldIn = false
    @State private var buttonIn = false

    /// Observed keyboard height. SwiftUI's automatic keyboard
    /// avoidance does not work reliably from inside the ZStack
    /// overlay that hosts AddBond (HomeView mounts AddBond as a
    /// sibling overlay, not a sheet or push), so we listen for
    /// the UIKit notifications ourselves and lift the layout by
    /// exactly the keyboard's overlap with the screen.
    @State private var keyboardHeight: CGFloat = 0

    private var canSave: Bool {
        store.birthPlace != nil
    }

    /// True while the search field is focused (i.e. the user
    /// tapped the pill — not strictly while typing). Drives the
    /// collapsing of hero + title and the "field on top, results
    /// below" layout. Re-shows the editorial chrome the moment
    /// the field loses focus (result tap, manual dismiss, back).
    @State private var fieldIsFocused: Bool = false

    var body: some View {
        // While the user is actively typing, the hero blob and
        // editorial copy fade out so the field + dropdown can
        // have all of the upper screen — but the save button
        // stays put at the bottom so the user can commit the
        // selection without dismissing the keyboard manually
        // first. Without hiding hero/text the combined content
        // (hero + text + dropdown + field + save) overflows the
        // unobscured area on real devices and the field slides
        // under the keyboard.
        VStack(spacing: 0) {
            if !fieldIsFocused {
                Spacer(minLength: 72)

                heroBlock
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))

                Spacer(minLength: 18)

                textBlock
                    .transition(.opacity.combined(with: .offset(y: -10)))

                Spacer(minLength: 24)
            } else {
                // Rigid 72pt top inset (not a Spacer) so all of
                // the slack space flows to the *bottom* Spacer —
                // the field stays anchored just below the back
                // button while the dropdown below it gets all the
                // room it needs to expand downward.
                Color.clear.frame(height: 72)
            }

            placesField

            Spacer(minLength: 18)

            saveButton
                .padding(.bottom, 24)
        }
        .padding(.horizontal, AppLayout.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Pad the bottom by the live keyboard overlap. The
        // observer below tracks the keyboard's frame so the layout
        // shrinks (pushing the field above the keyboard) the
        // moment it appears and recovers when it dismisses.
        .padding(.bottom, keyboardHeight)
        .animation(.easeInOut(duration: 0.22), value: fieldIsFocused)
        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillShowNotification
            )
        ) { notification in
            guard
                let frame = notification.userInfo?[
                    UIResponder.keyboardFrameEndUserInfoKey
                ] as? CGRect
            else { return }
            // Use the keyboard frame height directly — on iPhone
            // the keyboard sits at the bottom of the window so its
            // frame height equals the overlap. This is simpler and
            // more reliable than coordinate-converting through the
            // key window (which can mis-fire when the AddBond
            // overlay is presented from a ZStack).
            keyboardHeight = frame.height
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillChangeFrameNotification
            )
        ) { notification in
            guard
                let frame = notification.userInfo?[
                    UIResponder.keyboardFrameEndUserInfoKey
                ] as? CGRect
            else { return }
            keyboardHeight = frame.height
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillHideNotification
            )
        ) { _ in
            keyboardHeight = 0
        }
        .onAppear {
            // Rehydrate the search field if the user navigates back
            // here after picking a place — keeps the displayed value
            // in sync with `store.birthPlace`.
            if let existing = store.birthPlace {
                searchText = existing.displayName
                selectedPlace = PlacesAutocompleteTextField.SelectedPlace(
                    placeId: existing.placeId,
                    name: existing.displayName,
                    formattedAddress: existing.displayName,
                    latitude: existing.latitude,
                    longitude: existing.longitude,
                    timezone: existing.timezone
                )
            }
            animateIn()
        }
        .onChange(of: selectedPlace) { _, newValue in
            if let p = newValue {
                store.birthPlace = BondBirthPlace(
                    placeId: p.placeId,
                    displayName: p.formattedAddress,
                    latitude: p.latitude,
                    longitude: p.longitude,
                    timezone: p.timezone
                )
            } else {
                store.birthPlace = nil
            }
        }
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
                .birthPlaceBreathing(enabled: true)
                .scaleEffect(blobIn ? 1.0 : 0.86)
                .opacity(blobIn ? 1 : 0)
        }
        .frame(height: 180)
    }

    // MARK: - Text

    private var textBlock: some View {
        VStack(spacing: 0) {
            Text("Their birthplace")
                .font(.raleway("SemiBold", size: 12, relativeTo: .caption2))
                .tracking(1.4)
                .foregroundStyle(DesignColors.textSecondary)
                .textCase(.uppercase)
                .opacity(eyebrowIn ? 1 : 0)
                .offset(y: eyebrowIn ? 0 : 10)

            Text("Where were\nthey born?")
                .font(.raleway("Bold", size: 30, relativeTo: .title))
                .tracking(-0.5)
                .foregroundStyle(DesignColors.textPrincipal)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 12)
                .opacity(titleIn ? 1 : 0)
                .offset(y: titleIn ? 0 : 12)

            Text("City, town, or village. We use this to compute the rhythms you share.")
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

    // MARK: - Places field

    private var placesField: some View {
        BondPlaceField(
            text: $searchText,
            selectedPlace: $selectedPlace,
            placeholder: "Search a place",
            onFocusChange: { focused in
                fieldIsFocused = focused
            }
        )
        .opacity(fieldIn ? 1 : 0)
        .offset(y: fieldIn ? 0 : 12)
    }

    // MARK: - CTA

    private var saveButton: some View {
        // Two-layer cross-fade rather than a global opacity dim.
        // Dimming `WarmCapsuleButton` to look "disabled" washed
        // the white label out against the dimmed warm gradient.
        // Instead we stack the active capsule with a dedicated
        // disabled stand-in (muted dusty-rose surface, dark text
        // on `textSecondary`) and toggle their opacities. The two
        // share padding so the geometry is identical and the
        // crossfade reads as one button changing state.
        ZStack {
            WarmCapsuleButton(
                "Sync the rhythms",
                prominence: .primary,
                isFullWidth: false
            ) {
                store.send(.birthPlaceContinueTapped)
            }
            .opacity(canSave ? 1 : 0)

            disabledSaveButton
                .opacity(canSave ? 0 : 1)
                .allowsHitTesting(false)
        }
        .opacity(buttonIn ? 1 : 0)
        .scaleEffect(buttonIn ? 1.0 : 0.94)
        .animation(.easeOut(duration: 0.25), value: canSave)
    }

    private var disabledSaveButton: some View {
        Text("Sync the rhythms")
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
        withAnimation(.easeOut(duration: 1.0)) { watermarkIn = true }
        withAnimation(.spring(response: 0.85, dampingFraction: 0.82).delay(0.15)) {
            blobIn = true
        }
        withAnimation(.easeOut(duration: 0.65).delay(0.38)) { eyebrowIn = true }
        withAnimation(.easeOut(duration: 0.7).delay(0.5)) { titleIn = true }
        withAnimation(.easeOut(duration: 0.65).delay(0.64)) { bodyIn = true }
        withAnimation(.easeOut(duration: 0.6).delay(0.78)) { fieldIn = true }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.92)) {
            buttonIn = true
        }
    }
}

// MARK: - Subtle breathing modifier (file-local copy)

private struct BirthPlaceBreathingModifier: ViewModifier {
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
    func birthPlaceBreathing(enabled: Bool) -> some View {
        modifier(BirthPlaceBreathingModifier(enabled: enabled))
    }
}

#Preview {
    AddBondView(
        store: .init(initialState: AddBondFeature.State(step: .birthPlace)) {
            AddBondFeature()
        },
        onDismiss: {}
    )
}
