import SwiftUI

// MARK: - Rhythm Reflection Share Screen
//
// Preview cover the user lands on after tapping share on the Cycle
// Stats reflection card. Shows the exact card the image will become,
// framed on a warm background, with only a back button and a share
// trigger. Deliberately no "Instagram Story" shortcut — the
// reflection copy is editorial, not social-post punchy, and a story
// button pushes the tone in the wrong direction.

struct RhythmReflectionShareScreen: View {
    let copy: String
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
        ZStack {
            GradientBackground()
                .ignoresSafeArea()

            VStack(spacing: 32) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Spacer(minLength: 0)

                previewCard
                    .padding(.horizontal, 28)

                Spacer(minLength: 0)
            }
        }
        .task {
            if renderedImage == nil {
                renderedImage = Self.renderImage(copy: copy)
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

    @ViewBuilder
    private var topBar: some View {
        HStack {
            circleButton(systemName: "chevron.left", label: "Close", action: onDismiss)
            Spacer()
            circleButton(systemName: "square.and.arrow.up", label: "Share", action: share)
        }
    }

    @ViewBuilder
    private func circleButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DesignColors.text)
                .frame(width: 44, height: 44)
                .background { Circle().fill(.ultraThinMaterial) }
                .overlay { Circle().stroke(DesignColors.text.opacity(0.08), lineWidth: 0.6) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @MainActor
    private func share() {
        // Reuse the already-rendered preview image so the user
        // shares the exact same pixels they saw on screen.
        let image = renderedImage ?? Self.renderImage(copy: copy)
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
    private static func renderImage(copy: String) -> UIImage? {
        let renderer = ImageRenderer(
            content: RhythmReflectionShareView(copy: copy)
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

    var body: some View {
        ZStack {
            Color.white

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Text(copy)
                    .font(.system(size: 62, weight: .regular, design: .serif))
                    .italic()
                    .tracking(-0.6)
                    .foregroundStyle(DesignColors.accentWarmText)
                    .lineSpacing(12)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 80)

                Spacer(minLength: 0)

                // Wordmark – lower-case lockup, Raleway Bold, muted
                // warm tone. Reads as signature, not as logo shout.
                Text("cycle")
                    .font(.raleway("Bold", size: 44, relativeTo: .largeTitle))
                    .tracking(-0.6)
                    .foregroundStyle(DesignColors.accentWarmText.opacity(0.85))
                    .padding(.bottom, 72)
            }
            .padding(.top, 72)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
