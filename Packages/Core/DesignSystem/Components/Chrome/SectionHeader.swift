import SwiftUI

// MARK: - Section Header

/// Unified section title used on Home and sheets. Renders outside the content
/// card it introduces, giving the screen a consistent editorial rhythm.
///
///     SectionHeader(title: "Wellness", trailing: "Luteal · Day 26")
///     SectionHeader(title: "Your day", trailingContent: { positionDots })
///
/// Titles are `Raleway Bold 22` and carry the `.isHeader` accessibility
/// trait. The trailing slot is optional and accepts either a short meta
/// string or an arbitrary SwiftUI view (for dots, chevron links, etc).
public struct SectionHeader<Trailing: View>: View {
    public let title: String
    public let trailing: Trailing

    public init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            Text(title)
                .font(.raleway("Bold", size: 22, relativeTo: .title2))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            trailing
        }
        .padding(.horizontal, AppLayout.horizontalPadding)
        .padding(.top, 24)
        .padding(.bottom, 10)
    }
}

// Convenience overload for the common "title + meta string" case.
public extension SectionHeader where Trailing == SectionHeaderMeta {
    init(title: String, trailing: String? = nil) {
        self.init(title: title) {
            SectionHeaderMeta(text: trailing)
        }
    }
}

/// Small trailing meta label used by the convenience initializer. Renders
/// nothing when `text` is nil so the header layout collapses cleanly.
public struct SectionHeaderMeta: View {
    public let text: String?

    public var body: some View {
        if let text, !text.isEmpty {
            Text(text)
                .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)
        } else {
            EmptyView()
        }
    }
}
