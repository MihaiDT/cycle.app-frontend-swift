import ComposableArchitecture
import SwiftUI

// MARK: - Add Bond — Intro Screen
//
// First screen of the AddBond flow. Editorial, intimate. Hero blob
// pair (you + empty other) breathes calmly in the centre, framed by
// the Venn watermark that hints "the space between". Body copy
// explains what a bond is. Single primary CTA — "Begin" — advances
// to the name step. Dismissal is handled by the persistent back
// button in AddBondView's chrome (no secondary "Maybe later").

struct AddBondIntroView: View {
    @Bindable var store: StoreOf<AddBondFeature>
    let onDismiss: () -> Void

    // Staggered entrance flags. Flipped in `animateIn()` so the hero
    // settles before the copy cascades and the CTA lands last — keeps
    // the feel calm/editorial rather than everything popping at once.
    @State private var watermarkIn = false
    @State private var blobsIn = false
    @State private var eyebrowIn = false
    @State private var titleIn = false
    @State private var bodyIn = false
    @State private var buttonIn = false

    var body: some View {
        VStack(spacing: 0) {
            // Top inset matches the persistent close X height + its
            // 16pt offset from the safe area, so the hero never sits
            // under the chrome on smaller devices.
            Spacer(minLength: 72)

            heroBlock

            Spacer(minLength: 24)

            textBlock

            Spacer(minLength: 32)

            beginButton
                .padding(.bottom, 24)
        }
        .padding(.horizontal, AppLayout.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: animateIn)
    }

    // MARK: - Hero (blob pair + venn watermark)

    private var heroBlock: some View {
        ZStack {
            VennCirclesWatermark(
                strokeColor: DesignColors.accentWarm,
                lineWidth: 1.8,
                opacity: 0.18,
                circleSize: 220,
                overlap: 90
            )
            .scaleEffect(watermarkIn ? 1.0 : 0.92)
            .opacity(watermarkIn ? 1 : 0)

            BondBlobPair(
                leftAsset: "BondBlobYou",
                rightAsset: "BondBlobEmpty",
                leftRotation: -12,
                rightRotation: 140,
                size: 180,
                overlap: 28,
                breathing: true
            )
            .scaleEffect(blobsIn ? 1.0 : 0.86)
            .opacity(blobsIn ? 1 : 0)
        }
        .frame(height: 240)
    }

    // MARK: - Text (eyebrow + title + body)

    private var textBlock: some View {
        VStack(spacing: 0) {
            Text("Add a bond")
                .font(.raleway("SemiBold", size: 12, relativeTo: .caption2))
                .tracking(1.4)
                .foregroundStyle(DesignColors.textSecondary)
                .textCase(.uppercase)
                .opacity(eyebrowIn ? 1 : 0)
                .offset(y: eyebrowIn ? 0 : 10)

            Text("Tell your story\ntogether")
                .font(.raleway("Bold", size: 34, relativeTo: .title))
                .tracking(-0.6)
                .foregroundStyle(DesignColors.textPrincipal)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 14)
                .opacity(titleIn ? 1 : 0)
                .offset(y: titleIn ? 0 : 12)

            Text("Add someone close to you - a partner, a friend, anyone you choose. We'll read what's between you, what flows, where you spark.")
                .font(.raleway("Medium", size: 16, relativeTo: .body))
                .tracking(0.1)
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)
                .padding(.horizontal, 4)
                .opacity(bodyIn ? 1 : 0)
                .offset(y: bodyIn ? 0 : 10)
        }
    }

    // MARK: - CTA

    private var beginButton: some View {
        WarmCapsuleButton(
            "Begin",
            prominence: .primary,
            isFullWidth: false
        ) {
            store.send(.beginTapped)
        }
        .opacity(buttonIn ? 1 : 0)
        .scaleEffect(buttonIn ? 1.0 : 0.94)
    }

    // MARK: - Entrance animation

    private func animateIn() {
        // Watermark eases in first as the quiet "stage".
        withAnimation(.easeOut(duration: 1.1)) {
            watermarkIn = true
        }
        // Blobs land just after, slightly scaled up from below.
        withAnimation(.spring(response: 0.9, dampingFraction: 0.82).delay(0.18)) {
            blobsIn = true
        }
        // Copy cascades down — eyebrow → title → body.
        withAnimation(.easeOut(duration: 0.7).delay(0.45)) {
            eyebrowIn = true
        }
        withAnimation(.easeOut(duration: 0.75).delay(0.58)) {
            titleIn = true
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.74)) {
            bodyIn = true
        }
        // CTA lands last so the eye comes to rest on it.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.95)) {
            buttonIn = true
        }
    }
}

#Preview {
    AddBondView(
        store: .init(initialState: AddBondFeature.State(step: .intro)) {
            AddBondFeature()
        },
        onDismiss: {}
    )
}
