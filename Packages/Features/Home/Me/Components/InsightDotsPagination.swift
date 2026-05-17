import SwiftUI

// MARK: - Insight Dots Pagination
//
// Three dots used below the Daily Insight card. The active dot
// stretches to a 16x5pt capsule in `accentWarm`; the rest are 5pt
// circles muted to text.opacity(0.18). Tap propagates the new index
// via the `onSelect` closure.

public struct InsightDotsPagination: View {
    public let activeIndex: Int
    public let totalCount: Int
    public let onSelect: (Int) -> Void

    public init(
        activeIndex: Int,
        totalCount: Int = 3,
        onSelect: @escaping (Int) -> Void = { _ in }
    ) {
        self.activeIndex = activeIndex
        self.totalCount = totalCount
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalCount, id: \.self) { index in
                Button {
                    onSelect(index)
                } label: {
                    pill(isActive: index == activeIndex)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Page \(index + 1) of \(totalCount)")
            }
        }
    }

    @ViewBuilder
    private func pill(isActive: Bool) -> some View {
        if isActive {
            Capsule()
                .fill(DesignColors.accentWarm)
                .frame(width: 16, height: 5)
        } else {
            Circle()
                .fill(DesignColors.text.opacity(0.18))
                .frame(width: 5, height: 5)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        InsightDotsPagination(activeIndex: 0)
        InsightDotsPagination(activeIndex: 1)
        InsightDotsPagination(activeIndex: 2)
    }
    .padding(40)
    .background(DesignColors.background)
}
