import SwiftUI

// MARK: - Cycle Stats Loading Skeletons
//
// One view per data-dependent card. Each mirrors its real
// counterpart's outer chrome (`widgetCardStyle`, padding) and
// approximate height so the swap from skeleton to real card is a
// pure content change with no layout reflow.
//
// Pure static shapes — no pulse/shimmer — because a repeatForever
// animation invalidates the outer scroll's bitmap cache and was
// measured as a jank source on earlier iterations.

private enum SkeletonStyle {
    static var blockColor: Color { DesignColors.text.opacity(0.08) }
}

private struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var radius: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(SkeletonStyle.blockColor)
            .frame(width: width, height: height)
    }
}

// MARK: - Overview row (two small tiles)

struct CycleStatsOverviewSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            cell
            cell
        }
    }

    private var cell: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonBlock(width: 70, height: 9, radius: 3)
            SkeletonBlock(width: 60, height: 22)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 20)
    }
}

// MARK: - Normality card

struct CycleNormalitySkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SkeletonBlock(width: 150, height: 20)
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBlock(width: 45, height: 9, radius: 3)
                        SkeletonBlock(width: 52, height: 20)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            SkeletonBlock(height: 10, radius: 3)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }
}

// MARK: - History card

struct CycleHistorySkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                SkeletonBlock(width: 130, height: 20)
                Spacer()
                SkeletonBlock(width: 50, height: 12, radius: 3)
            }
            VStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { idx in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            SkeletonBlock(width: 90, height: 14)
                            Spacer()
                            SkeletonBlock(width: 40, height: 12, radius: 3)
                        }
                        SkeletonBlock(height: 6, radius: 3)
                    }
                    if idx < 2 {
                        Rectangle()
                            .fill(DesignColors.text.opacity(DesignColors.dividerOpacity))
                            .frame(height: 1)
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }
}

// MARK: - Average cycle card

struct AvgCycleSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(width: 150, height: 22)
                SkeletonBlock(width: 190, height: 22)
            }
            SkeletonBlock(width: 140, height: 52, radius: 6)
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    SkeletonBlock(width: 50, height: 9, radius: 3)
                    SkeletonBlock(width: 80, height: 18, radius: 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle()
                    .fill(DesignColors.text.opacity(DesignColors.dividerOpacity))
                    .frame(width: 1, height: 34)
                VStack(alignment: .leading, spacing: 5) {
                    SkeletonBlock(width: 55, height: 9, radius: 3)
                    SkeletonBlock(width: 70, height: 18, radius: 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
            }
            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(height: 12, radius: 3)
                SkeletonBlock(width: 180, height: 12, radius: 3)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }
}
