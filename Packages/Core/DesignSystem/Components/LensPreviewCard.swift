import SwiftUI

// MARK: - Lens Preview Card
//
// A beautiful preview tile that hooks the user into Lens. Tonal gradient
// background keyed off `preview.tone`, editorial typography, minimal
// chrome. Tap fires the `onOpen` closure which is expected to navigate
// the user to Lens with the preview's payload.

public struct LensPreviewCard: View {
    public let preview: LensPreview
    public let variation: Int
    public let onOpen: (() -> Void)?

    public init(
        preview: LensPreview,
        variation: Int = 0,
        onOpen: (() -> Void)? = nil
    ) {
        self.preview = preview
        self.variation = variation
        self.onOpen = onOpen
    }

    public var body: some View {
        Button(action: { onOpen?() }) {
            VStack(alignment: .leading, spacing: 14) {
                metaRow
                title
                teaser
                Spacer(minLength: 0)
                cta
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
            .background(auroraBackground)
            // Clip on the outer view so blobs + their blur halos stay
            // inside the rounded rect. `.clipShape` inside the background
            // sometimes leaks because the background sizes to parent but
            // the clip may not cover the blur overflow.
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(onOpen == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preview.title). \(preview.teaser)")
        .accessibilityHint("Opens in Lens, \(preview.durationMinutes) minute session")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Meta row (LENS · 5 MIN · LUTEAL)

    @ViewBuilder
    private var metaRow: some View {
        let parts = [
            "LENS",
            "\(preview.durationMinutes) MIN",
            preview.phase.displayName.uppercased()
        ]
        Text(parts.joined(separator: " · "))
            .font(.raleway("SemiBold", size: 10, relativeTo: .caption2))
            .tracking(1.0)
            .foregroundStyle(DesignColors.text.opacity(0.55))
    }

    // MARK: Title

    @ViewBuilder
    private var title: some View {
        Text(preview.title)
            .font(.raleway("Bold", size: 22, relativeTo: .title3))
            .tracking(-0.3)
            .foregroundStyle(DesignColors.text)
            .lineSpacing(2)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Teaser

    @ViewBuilder
    private var teaser: some View {
        Text(preview.teaser)
            .font(.raleway("Medium", size: 13, relativeTo: .body))
            .foregroundStyle(DesignColors.text.opacity(0.72))
            .lineSpacing(3)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: CTA

    @ViewBuilder
    private var cta: some View {
        HStack(spacing: 6) {
            Text("Open in Lens")
                .font(.raleway("SemiBold", size: 13, relativeTo: .callout))
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(DesignColors.accentWarmText)
        .padding(.top, 4)
    }

    // MARK: Aurora background
    //
    // Shared palette across every card — three soft, blurred blobs
    // floating over a cream base. The `variation` parameter shifts
    // where each blob sits so neighbouring cards don't look like
    // carbon copies while keeping them visually "equal".

    @ViewBuilder
    private var auroraBackground: some View {
        ZStack {
            DesignColors.background

            auroraBlob(
                color: Color(hex: 0xF3C9C2),      // warm rose
                diameter: 220,
                offset: blob0Offset
            )
            auroraBlob(
                color: Color(hex: 0xF1D9A8),      // golden peach
                diameter: 200,
                offset: blob1Offset
            )
            auroraBlob(
                color: Color(hex: 0xD4C2DE),      // dusk lavender
                diameter: 180,
                offset: blob2Offset
            )
        }
    }

    @ViewBuilder
    private func auroraBlob(
        color: Color,
        diameter: CGFloat,
        offset: CGSize
    ) -> some View {
        Circle()
            .fill(color.opacity(0.55))
            .frame(width: diameter, height: diameter)
            .blur(radius: 48)
            .offset(offset)
    }

    // Each variation shifts all three blobs, so cards feel cohesive but
    // never identical. Cycles through three patterns; anything beyond 3
    // reuses pattern 0.
    private var v: Int { ((variation % 3) + 3) % 3 }

    private var blob0Offset: CGSize {
        switch v {
        case 0: return CGSize(width: -110, height: -70)
        case 1: return CGSize(width: 120, height: -60)
        default: return CGSize(width: 0, height: -90)
        }
    }

    private var blob1Offset: CGSize {
        switch v {
        case 0: return CGSize(width: 130, height: 50)
        case 1: return CGSize(width: -120, height: 70)
        default: return CGSize(width: 140, height: 30)
        }
    }

    private var blob2Offset: CGSize {
        switch v {
        case 0: return CGSize(width: 40, height: 80)
        case 1: return CGSize(width: -40, height: -80)
        default: return CGSize(width: -140, height: 40)
        }
    }
}

// MARK: - Preview

#Preview("Stack") {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()
        ScrollView {
            VStack(spacing: 14) {
                LensPreviewCard(
                    preview: LensPreview(
                        title: "Why softness is strength",
                        teaser: "Luteal rest isn't weakness. Let's unpack what your body is actually asking for.",
                        durationMinutes: 5,
                        tone: .tender,
                        phase: .luteal,
                        cycleDay: 26
                    ),
                    variation: 0,
                    onOpen: {}
                )
                LensPreviewCard(
                    preview: LensPreview(
                        title: "The inner critic's favorite week",
                        teaser: "Progesterone amplifies the voice. Learn to hear it without obeying it.",
                        durationMinutes: 6,
                        tone: .reflective,
                        phase: .luteal,
                        cycleDay: 26
                    ),
                    variation: 1,
                    onOpen: {}
                )
                LensPreviewCard(
                    preview: LensPreview(
                        title: "Winding down with intention",
                        teaser: "Three closing practices that turn the late-luteal drag into something graceful.",
                        durationMinutes: 5,
                        tone: .grounding,
                        phase: .luteal,
                        cycleDay: 26
                    ),
                    variation: 2,
                    onOpen: {}
                )
            }
            .padding(18)
        }
    }
}
