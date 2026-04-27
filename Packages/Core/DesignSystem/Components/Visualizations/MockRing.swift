import SwiftUI

// MARK: - Mock Ring
//
// Decorative ring used in the corner of stat tiles (Avg cycle / Avg
// period and similar). Reads as a quiet visual anchor that ties the
// tile's accent color to its numeric value, without competing with
// the data for attention. Carries no semantic information — it is
// not a progress indicator. Hidden from accessibility for that
// reason: a screen reader user gains nothing from "75% of a circle".
//
// The default ~78% trim leaves an open arc at the top-right, which
// matches the "unfinished progress" silhouette without implying
// real progress data behind it.

public struct MockRing: View {
    public let tint: Color
    public let size: CGFloat
    public let lineWidth: CGFloat
    /// Fraction of the circumference drawn by the foreground stroke
    /// (0...1). On a tile with no track this is the whole ring; on a
    /// tile with a track this is the "filled" portion painted over
    /// the track.
    public let trim: CGFloat
    /// Optional background track tint. When set together with
    /// `trackTrim`, MockRing renders two stacked arcs — track first,
    /// then the foreground stroke on top — which lets a tile read as
    /// a progress ring with context (e.g. red period days inside the
    /// quieter cycle window).
    public let trackTint: Color?
    /// Fraction of the circumference drawn by the track. Should be
    /// `>= trim` so the fill always sits on top of (not past) the
    /// track.
    public let trackTrim: CGFloat?

    public init(
        tint: Color,
        size: CGFloat = 28,
        lineWidth: CGFloat = 2.5,
        trim: CGFloat = 0.78,
        trackTint: Color? = nil,
        trackTrim: CGFloat? = nil
    ) {
        self.tint = tint
        self.size = size
        self.lineWidth = lineWidth
        self.trim = trim
        self.trackTint = trackTint
        self.trackTrim = trackTrim
    }

    public var body: some View {
        ZStack {
            if let trackTint, let trackTrim {
                Circle()
                    .trim(from: 0, to: trackTrim)
                    .stroke(
                        trackTint,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            Circle()
                .trim(from: 0, to: trim)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Mock Ring – sizes & tints") {
    HStack(spacing: 24) {
        MockRing(tint: DesignColors.roseTaupe)
        MockRing(tint: DesignColors.accentWarm, size: 40, lineWidth: 3)
        MockRing(tint: DesignColors.accentHoney, size: 22, lineWidth: 2, trim: 0.65)
        MockRing(tint: DesignColors.accentSecondary, size: 56, lineWidth: 4, trim: 0.9)
    }
    .padding(40)
    .background(DesignColors.background)
}
#endif
