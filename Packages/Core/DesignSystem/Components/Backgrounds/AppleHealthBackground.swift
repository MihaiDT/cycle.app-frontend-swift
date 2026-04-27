import SwiftUI

// MARK: - Apple Health Background
//
// White-base background with a warm gradient wash at the top that
// fades out as the user reads down — same tonal recipe as Apple
// Health's Summary screen. The gradient sits behind the nav bar
// (consumer is expected to `.ignoresSafeArea` on its scroll
// content), so the title region reads as a soft warm atmosphere
// without painting the whole screen in color.
//
// Used as a swap for `JourneyAnimatedBackground` on data-forward
// screens (Cycle Stats) where the white cards need a clean canvas
// to pop. No decorative blobs, glows, or noise treatments —
// this background is supposed to recede.

public struct AppleHealthBackground: View {
    public let topTint: Color
    public let topHeight: CGFloat

    public init(
        topTint: Color = DesignColors.accent,
        topHeight: CGFloat = 320
    ) {
        self.topTint = topTint
        self.topHeight = topHeight
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.white

            LinearGradient(
                colors: [topTint, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: topHeight)
        }
        .ignoresSafeArea()
    }
}

#if DEBUG
#Preview("Apple Health Background – default (accent)") {
    AppleHealthBackground()
}

#Preview("Apple Health Background – dusty rose") {
    AppleHealthBackground(topTint: DesignColors.accentSecondary)
}
#endif
