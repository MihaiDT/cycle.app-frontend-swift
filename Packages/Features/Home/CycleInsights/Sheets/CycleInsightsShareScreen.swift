import SwiftUI

// MARK: - Rhythm Reflection Share Screen
//
// Preview cover the user lands on after tapping share on the Cycle
// Stats reflection card. Shows the exact card the image will become,
// framed on a warm background, with a back chevron, a top-right
// share trigger (full system sheet) and a phase-tinted "Share to
// Instagram Story" pill at the foot — the one-tap path users reach
// for first. The pill takes its colour from the phase palette so
// the affordance reads as an extension of the card it's sharing,
// not a stock CTA bolted on.

struct RhythmReflectionShareScreen: View {
    let copy: String
    let phase: CyclePhase?
    let onDismiss: () -> Void

    /// Pre-rendered export image. We render once at the full
    /// 1080×1350 export size, then display that `UIImage` in the
    /// preview scaled to fit. Running `RhythmReflectionShareView`
    /// directly in the view tree looks wrong because its font is
    /// sized for 1080pt width (62pt), so at a ~300pt preview frame
    /// the text explodes past the edges. The image approach makes
    /// the preview pixel-identical to what the user will share.
    @State private var renderedImage: UIImage?

    var body: some View {
        // Wrapped in `NavigationStack` so the back chevron and share
        // glyph render as native toolbar buttons — same point size,
        // same hit area, same tint as every other pushed screen on
        // Cycle Stats. The previous custom glass capsules were
        // off-spec next to the rest of the app's chrome.
        NavigationStack {
            ZStack {
                // Same warm peach surface as Cycle Stats / Cycle
                // Detail so the share preview reads as part of the
                // same flow, not a separate post-composer.
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                    }
                    .tint(DesignColors.text)
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: share) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .tint(DesignColors.text)
                    .accessibilityLabel("Share")
                }
            }
            .task {
                if renderedImage == nil {
                    renderedImage = Self.renderImage(copy: copy, phase: phase)
                }
            }
        }
    }

    @ViewBuilder
    private var previewCard: some View {
        if let renderedImage {
            Image(uiImage: renderedImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 10)
        } else {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .aspectRatio(1080.0 / 1350.0, contentMode: .fit)
                .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 10)
                .overlay {
                    ProgressView()
                        .tint(DesignColors.accentWarmText)
                }
        }
    }

    // MARK: - Instagram story pill
    //
    // One-tap hand-off to Instagram Stories. Uses the documented
    // `instagram-stories://share` URL scheme + `UIPasteboard` sticker
    // payload, so the rendered card lands as the story background and
    // the user can re-position, caption, or post immediately. Visual
    // is the app-wide white `glassEffectCapsule()` — same surface as
    // `GlassButton` / DailyCheckIn / Onboarding CTAs — so the
    // affordance reads as cycle.app's standard primary action, not a
    // bespoke share-screen widget.

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
        .accessibilityLabel("Share to Instagram Story")
    }

    @MainActor
    private func shareToInstagramStory() {
        // Render lazily if the user taps before `.task` finished —
        // tiny window, but the pill must never silently no-op.
        let image = renderedImage ?? Self.renderImage(copy: copy, phase: phase)
        guard let image, let imageData = image.pngData() else { return }

        guard let url = URL(string: "instagram-stories://share?source_application=\(Bundle.main.bundleIdentifier ?? "app.cycle.ios")") else { return }
        guard UIApplication.shared.canOpenURL(url) else {
            // Instagram not installed (or scheme not whitelisted in
            // Info.plist's `LSApplicationQueriesSchemes`) — fall back
            // to the system share sheet so the user still has a path
            // off this screen.
            share()
            return
        }

        // Pass the card as a *sticker* on a peach gradient backdrop —
        // not as `backgroundImage`. backgroundImage gets Instagram's
        // editor vignette painted over it (the whole canvas dims so
        // their UI chrome reads), which crushes the card's gradient
        // and turns the serif copy nearly black-on-black. Sticker
        // mode keeps the card untouched and lets us own the
        // surrounding colour with the two bg-colour keys, matching
        // the Cycle Stats peach surface.
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
        // Reuse the already-rendered preview image so the user
        // shares the exact same pixels they saw on screen.
        let image = renderedImage ?? Self.renderImage(copy: copy, phase: phase)
        let items: [Any] = image.map { [$0] } ?? [copy]
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
    private static func renderImage(copy: String, phase: CyclePhase?) -> UIImage? {
        let renderer = ImageRenderer(
            content: RhythmReflectionShareView(copy: copy, phase: phase)
                .frame(width: 1080, height: 1350)
        )
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

// MARK: - Share Image Template

/// Rendered both as the preview (scaled down inside the share
/// screen) and as the 1080×1350 export piped through `ImageRenderer`.
/// Runs at intrinsic size; callers frame it.

struct RhythmReflectionShareView: View {
    let copy: String
    let phase: CyclePhase?

    private var palette: SharePalette {
        SharePalette.forPhase(phase)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            backdrop
            watermark
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Backdrop

    /// Same three-layer composition as `CycleRhythmReflectionCard` —
    /// diagonal phase gradient + top-trailing radial highlight +
    /// bottom veil. Sized for the 1080×1350 export, so radius +
    /// offset numbers are scaled up vs. the in-app card.
    private var backdrop: some View {
        ZStack {
            LinearGradient(
                colors: palette.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.45),
                    Color.white.opacity(0.0)
                ],
                center: .init(x: 0.92, y: 0.05),
                startRadius: 20,
                endRadius: 1100
            )
            .blendMode(.softLight)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var watermark: some View {
        Image(systemName: palette.symbolName)
            .font(.system(size: 920, weight: .ultraLight))
            .foregroundStyle(palette.deep.opacity(0.05))
            .blur(radius: 90)
            .offset(x: 360, y: 250)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .clipped()
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text(formattedCopy)
                .font(.system(size: 62, weight: .regular, design: .serif))
                .italic()
                .tracking(-0.6)
                .foregroundStyle(palette.deep)
                .lineSpacing(12)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 96)

            Spacer(minLength: 0)

            footer
                .padding(.horizontal, 96)
                .padding(.bottom, 96)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Hard line break after every sentence — see the in-app card
    /// for why. The export image inherits the same rule so the
    /// preview, the in-app card and the Instagram sticker all break
    /// at the same places.
    private var formattedCopy: String {
        copy
            .replacingOccurrences(of: ". ", with: ".\n")
            .replacingOccurrences(of: "? ", with: "?\n")
            .replacingOccurrences(of: "! ", with: "!\n")
    }

    /// Wordmark on the left, attribution removed — the export keeps
    /// just the cycle.app signature.
    private var footer: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("cycle")
                .font(.raleway("Bold", size: 64, relativeTo: .largeTitle))
                .tracking(-1.0)
                .foregroundStyle(palette.deep.opacity(0.85))

            Spacer(minLength: 0)
        }
    }

    // MARK: - Phase palette
    //
    // Mirrors `CycleRhythmReflectionCard.PhasePalette` so the in-app
    // card and the exported image share the same colour vocabulary.

    fileprivate struct SharePalette {
        let gradient: [Color]
        let accent: Color
        let deep: Color
        let symbolName: String

        static func forPhase(_ phase: CyclePhase?) -> SharePalette {
            switch phase {
            case .menstrual:
                return SharePalette(
                    gradient: [
                        DesignColors.recapMenstrualStart.opacity(0.55),
                        DesignColors.calendarPeriodGlyph.opacity(0.30),
                        DesignColors.accent.opacity(0.55),
                        DesignColors.background
                    ],
                    accent: DesignColors.calendarPeriodGlyph,
                    deep: DesignColors.text,
                    symbolName: "drop.fill"
                )
            case .follicular:
                return SharePalette(
                    gradient: [
                        DesignColors.accentSecondary.opacity(0.55),
                        DesignColors.accent.opacity(0.65),
                        DesignColors.heroCreamBottom,
                        DesignColors.background
                    ],
                    accent: DesignColors.accentSecondary,
                    deep: DesignColors.accentWarmText,
                    symbolName: "leaf.fill"
                )
            case .ovulatory:
                return SharePalette(
                    gradient: [
                        DesignColors.accentHoney.opacity(0.55),
                        DesignColors.accent.opacity(0.55),
                        DesignColors.heroCreamBottom,
                        DesignColors.background
                    ],
                    accent: DesignColors.accentHoneyText,
                    deep: DesignColors.accentHoneyText,
                    symbolName: "sun.max.fill"
                )
            case .luteal:
                return SharePalette(
                    gradient: [
                        DesignColors.roseTaupe.opacity(0.55),
                        DesignColors.roseTaupeLight.opacity(0.65),
                        DesignColors.cardWarm,
                        DesignColors.background
                    ],
                    accent: DesignColors.roseTaupe,
                    deep: DesignColors.accentWarmText,
                    symbolName: "moon.stars.fill"
                )
            case .late:
                return SharePalette(
                    gradient: [
                        DesignColors.accentHoney.opacity(0.50),
                        DesignColors.roseTaupeLight.opacity(0.55),
                        DesignColors.cardWarm,
                        DesignColors.background
                    ],
                    accent: DesignColors.accentHoneyText,
                    deep: DesignColors.accentWarmText,
                    symbolName: "clock.fill"
                )
            case .none:
                return SharePalette(
                    gradient: [
                        DesignColors.accent.opacity(0.40),
                        DesignColors.heroCreamBottom,
                        DesignColors.background
                    ],
                    accent: DesignColors.accentWarm,
                    deep: DesignColors.accentWarmText,
                    symbolName: "sparkle"
                )
            }
        }
    }
}

