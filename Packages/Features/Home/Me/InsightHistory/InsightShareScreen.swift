import SwiftUI

// MARK: - Insight Share Screen
//
// Full-screen preview the user lands on after tapping a saved
// insight in the InsightHistory grid. Mirrors the structure of
// `RhythmReflectionShareScreen` (back chevron + native share
// trigger + Instagram Stories pill) but the rendered card is
// pixel-identical in spirit to the on-tab `DailyInsightCard` —
// ivory base + 4 phase-coloured corner blobs + the peach
// InsightLiquid asset + a frosted overlay + the editorial copy
// + cycle wordmark. So the user shares the card they liked, not
// a generic phase-tinted recap.

struct InsightShareScreen: View {
    let insight: DailyInsightItem
    let onDismiss: () -> Void

    /// SwiftUI's native modal-dismiss handle. Calling this from
    /// the back chevron tears down the `fullScreenCover` and
    /// SwiftUI writes nil back into the source-of-truth binding
    /// for us — much more reliable than mutating the TCA bindable
    /// directly mid-tap (which raced with the toolbar event in
    /// previous iterations and dropped writes intermittently).
    /// `onDismiss` is still invoked as a hook so the parent can
    /// run side-effects (e.g. clear `selectedInsight` defensively).
    @Environment(\.dismiss) private var dismiss

    /// Pre-rendered export image. We rasterise once at 1080×1350
    /// (the Instagram Stories aspect ratio used by every other
    /// share surface in the app) and then display the resulting
    /// `UIImage` scaled to fit. Running the share view live in
    /// the tree breaks because its text + blob sizes are tuned
    /// for the 1080pt canvas — at a ~300pt preview, the type
    /// explodes past the edges.
    @State private var renderedImage: UIImage?

    var body: some View {
        // Pushed natively into the parent's NavigationStack — no
        // inner NavigationStack here, otherwise the right-to-left
        // push lands inside a stack-inside-a-stack and the
        // toolbar items / back chevron get attached to the wrong
        // navigation bar.
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 0)

                previewCard
                    .padding(.horizontal, 28)

                Spacer(minLength: 0)

                instagramStoryButton
                    .padding(.horizontal, 28)
                    .padding(.bottom, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    // Defer dismiss to next runloop tick so the
                    // skeleton's 30Hz `TimelineView` invalidation
                    // doesn't race with the toolbar gesture
                    // (same family of bug as 10621).
                    DispatchQueue.main.async {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(DesignColors.text)
                }
                .glassToolbar()
                .accessibilityLabel("Close")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: share) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(DesignColors.text)
                }
                .glassToolbar()
                // Disable until the rasterised bitmap is ready —
                // tapping early would force a synchronous
                // MainActor render and lock the main thread.
                .disabled(renderedImage == nil)
                .accessibilityLabel("Share")
            }
        }
        .task {
            // Defer the synchronous ImageRenderer pass well past
            // the end of the navigation push so it can never land
            // on the last few frames of the slide-in animation
            // (which read as a jitter). Rendering a 1080×1350
            // canvas with four heavy blurs + ultraThinMaterial
            // typically takes 80–250ms on-device and is fully
            // synchronous on the MainActor — once it starts, the
            // main thread is locked. 600ms keeps it cleanly
            // after the ~350ms push, while the ProgressView
            // placeholder fills the gap.
            guard renderedImage == nil else { return }
            try? await Task.sleep(for: .milliseconds(600))
            renderedImage = Self.renderImage(insight: insight)
        }
    }

    private var previewCard: some View {
        // Crossfade between skeleton and rendered bitmap via
        // explicit if/else + matching `.transition(.opacity)` so
        // the skeleton is fully *removed* from the view tree
        // once the bitmap is ready. Critically, this stops the
        // skeleton's `TimelineView(.animation)` from invalidating
        // the view at 60Hz forever — that perpetual invalidation
        // was racing with the toolbar tap and making the back
        // chevron occasionally no-op.
        ZStack {
            if renderedImage == nil {
                skeletonCard
                    .transition(.opacity)
            }

            if let renderedImage {
                Image(uiImage: renderedImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 10)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: renderedImage != nil)
    }

    /// Loading placeholder shown while `ImageRenderer` is
    /// building the 1080×1350 bitmap. Deliberately *different*
    /// from the real card surface so the user can tell at a
    /// glance that something is loading — a soft warm-gray base
    /// (not the card's ivory) with a clearly visible shimmer
    /// band sweeping across it, plus the on-brand peach hint
    /// underneath so it still feels part of the app.
    private var skeletonCard: some View {
        ZStack {
            // Solid warm-gray base — visibly different from the
            // real card's ivory so the swap is obvious.
            DesignColors.text.opacity(0.10)

            // Soft peach hint so the loading state still feels
            // like it belongs to this surface family.
            DesignColors.calendarFollicularGlyph.opacity(0.18)
                .blur(radius: 40)
        }
        .aspectRatio(1080.0 / 1350.0, contentMode: .fit)
        .overlay {
            // Shimmer driven by `TimelineView(.animation)` so
            // the sweep runs on its own clock and never pollutes
            // SwiftUI's transaction system. An earlier
            // `withAnimation(.repeatForever) { phase = ... }`
            // version leaked the animation context into the
            // toolbar, which made the back / share buttons
            // appear to oscillate in a loop.
            // Throttled to ~30Hz instead of `.animation` (which
            // adapts to the device's preferred 60–120Hz). A slow
            // shimmer band reads identically at half the refresh
            // rate, and the lower invalidation pressure reduces
            // toolbar-tap races with the dismiss gesture.
            TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                // 1.0s period, phase walks -0.3 → 1.3.
                let t = context.date.timeIntervalSinceReferenceDate
                let cycle = 1.0
                let progress = (t.truncatingRemainder(dividingBy: cycle)) / cycle
                let phase = CGFloat(progress) * 1.6 - 0.3

                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0), location: max(0, phase - 0.28)),
                        .init(color: .white.opacity(0.85), location: max(0, min(1, phase))),
                        .init(color: .white.opacity(0), location: min(1, phase + 0.28)),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .blendMode(.plusLighter)
            }
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 10)
    }

    @ViewBuilder
    private var instagramStoryButton: some View {
        Button(action: shareToInstagramStory) {
            HStack(spacing: 12) {
                Image("Instagram")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                Text("Share to Instagram Story")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignColors.text)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 55)
            .glassEffectCapsule()
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 0)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        // Same reason as the toolbar share button: the share
        // path falls back to a synchronous MainActor render if
        // the bitmap isn't ready, which would freeze the UI for
        // a couple hundred milliseconds right when the user taps.
        .disabled(renderedImage == nil)
        .opacity(renderedImage == nil ? 0.6 : 1.0)
        .accessibilityLabel("Share to Instagram Story")
    }

    @MainActor
    private func shareToInstagramStory() {
        let image = renderedImage ?? Self.renderImage(insight: insight)
        guard let image, let imageData = image.pngData() else { return }

        guard let url = URL(string: "instagram-stories://share?source_application=\(Bundle.main.bundleIdentifier ?? "app.cycle.ios")") else { return }
        guard UIApplication.shared.canOpenURL(url) else {
            share()
            return
        }

        // Sticker mode (not backgroundImage) so Instagram's editor
        // vignette doesn't darken our peach surface — same call
        // pattern as RhythmReflectionShareScreen.
        let pasteboardItems: [String: Any] = [
            "com.instagram.sharedSticker.stickerImage": imageData,
            "com.instagram.sharedSticker.backgroundTopColor": "#F8E6D2",
            "com.instagram.sharedSticker.backgroundBottomColor": "#EDC8AC"
        ]
        UIPasteboard.general.setItems(
            [pasteboardItems],
            options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
        )

        UIApplication.shared.open(url)
    }

    @MainActor
    private func share() {
        let image = renderedImage ?? Self.renderImage(insight: insight)
        let items: [Any] = image.map { [$0] } ?? [insight.text]
        let activity = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }
        presenter.present(activity, animated: true)
    }

    @MainActor
    private static func renderImage(insight: DailyInsightItem) -> UIImage? {
        let renderer = ImageRenderer(
            content: InsightShareView(insight: insight)
                .frame(width: 1080, height: 1350)
        )
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

// MARK: - Share Image Template
//
// 1080×1350 renderable card that mirrors the on-tab DailyInsightCard:
// ivory base + 4 phase-coloured corner blobs + the peach
// InsightLiquid asset + frosted overlay + a phase pill at the top
// + the insight copy centred + the cycle wordmark at the bottom.
// Numbers are scaled up from the in-app card (220pt minHeight →
// 1350pt canvas, so ~6.1× linear).

struct InsightShareView: View {
    let insight: DailyInsightItem

    var body: some View {
        ZStack {
            cardSurface

            VStack(spacing: 56) {
                Spacer(minLength: 0)

                phasePill

                Text(insight.text)
                    .font(.raleway("Medium", size: 110, relativeTo: .largeTitle))
                    .tracking(-1.6)
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(18)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 96)

                Spacer(minLength: 0)

                wordmark
                    .padding(.bottom, 80)
            }
            .padding(.horizontal, 120)
            .padding(.vertical, 140)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 1080-pt-canvas mirror of `DailyInsightCard.cardSurface`.
    /// All radii / offsets are scaled to roughly 6× the in-app
    /// numbers (220pt → 1350pt) so the visual ratios stay
    /// identical and the export reads as the same card the user
    /// hearted on the Me tab.
    private var cardSurface: some View {
        ZStack {
            DesignColors.background

            // Top-leading — period rose
            Circle()
                .fill(DesignColors.calendarPeriodGlyph.opacity(0.18))
                .frame(width: 900, height: 900)
                .blur(radius: 180)
                .offset(x: -520, y: -520)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Top-trailing — follicular oat
            Circle()
                .fill(DesignColors.calendarFollicularGlyph.opacity(0.34))
                .frame(width: 820, height: 820)
                .blur(radius: 170)
                .offset(x: 520, y: -460)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            // Bottom-leading — fertile sand
            Circle()
                .fill(DesignColors.calendarFertileGlyph.opacity(0.22))
                .frame(width: 900, height: 900)
                .blur(radius: 180)
                .offset(x: -460, y: 460)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            // Bottom-trailing — luteal mauve (paired with the liquid)
            Circle()
                .fill(DesignColors.calendarLutealGlyph.opacity(0.24))
                .frame(width: 820, height: 820)
                .blur(radius: 170)
                .offset(x: 460, y: 520)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            // Soft glass frost ties everything together
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.22)
        }
        .overlay(alignment: .bottomTrailing) {
            // Peach liquid overflow accent. Asset is only
            // 359×390 source pixels — the original 1320pt frame
            // upscaled it ~11× and baked visible pixelation into
            // the share bitmap. 720pt with `.interpolation(.high)`
            // keeps a meaningful visual presence while staying
            // smooth (the blob is soft / no hard edges so the
            // ~6× upscale resamples cleanly). Bump the source
            // asset to ~1500×1500 to restore the larger original
            // 1320pt visual without artifacts.
            Image("InsightLiquid")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 720, height: 720)
                .opacity(0.80)
                .offset(x: 180, y: 210)
        }
    }

    private var phasePill: some View {
        Text(insight.phaseLabel)
            .font(.raleway("SemiBold", size: 44, relativeTo: .title3))
            .tracking(-0.4)
            .foregroundStyle(DesignColors.text)
            .padding(.horizontal, 56)
            .padding(.vertical, 28)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 2)
            )
            .shadow(color: DesignColors.text.opacity(0.10), radius: 30, x: 0, y: 12)
    }

    private var wordmark: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("cycle")
                .font(.raleway("Bold", size: 64, relativeTo: .largeTitle))
                .tracking(-1.0)
                .foregroundStyle(DesignColors.text.opacity(0.85))

            Spacer(minLength: 0)
        }
    }
}

#Preview("Share preview") {
    InsightShareScreen(
        insight: DailyInsightItem(
            phaseLabel: "Luteal",
            text: "Soften the edges of your week. The body is asking for less.",
            italicSuffix: "less."
        ),
        onDismiss: {}
    )
}

#Preview("Export view raw") {
    InsightShareView(
        insight: DailyInsightItem(
            phaseLabel: "Follicular",
            text: "Begin again — gently.",
            italicSuffix: "gently."
        )
    )
    .frame(width: 1080, height: 1350)
    .scaleEffect(0.3)
}
