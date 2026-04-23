import SwiftUI

// MARK: - Latest Story Tile
//
// Warm peach-rose tile surfacing the user's most recent cycle recap.
// Tap opens that specific recap directly (skips the Journey full-screen
// step). Pair with `AllStoriesTile` on Home's Journey carousel page.

public struct LatestStoryTile: View {
    public let title: String
    public let snippet: String
    public let dateLabel: String
    public let isNew: Bool
    public let onTap: (() -> Void)?

    public init(
        title: String,
        snippet: String,
        dateLabel: String,
        isNew: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.snippet = snippet
        self.dateLabel = dateLabel
        self.isNew = isNew
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: { onTap?() }) {
            tileContent
                .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
                .background(background)
                .overlay(border)
                .shadow(color: Color(hex: 0xA64A3C).opacity(0.08), radius: 10, x: 0, y: 4)
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Latest story. \(title). \(snippet). \(dateLabel)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var tileContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow
            Spacer(minLength: 6)
            titleBlock
            Spacer(minLength: 8)
            bottomRow
        }
        .padding(18)
    }

    @ViewBuilder
    private var topRow: some View {
        HStack(alignment: .center) {
            Text("LATEST STORY")
                .font(.raleway("SemiBold", size: 10, relativeTo: .caption))
                .tracking(1.5)
                .foregroundStyle(Color(hex: 0x8C3E36).opacity(0.85))

            Spacer()

            if isNew {
                Text("NEW")
                    .font(.raleway("Black", size: 9, relativeTo: .caption2))
                    .tracking(0.5)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: 0x8C3E36)))
            }
        }
    }

    @ViewBuilder
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.raleway("Bold", size: 20, relativeTo: .title3))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(snippet)
                .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                .italic()
                .foregroundStyle(Color(hex: 0x5C3B30))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private var bottomRow: some View {
        HStack(alignment: .center) {
            Text(dateLabel)
                .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                .tracking(0.5)
                .foregroundStyle(Color(hex: 0x8C3E36))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: 0x8C3E36))
        }
    }

    @ViewBuilder
    private var background: some View {
        LinearGradient(
            colors: [Color(hex: 0xFCE6D4), Color(hex: 0xF3C9C2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var border: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Color(hex: 0xA64A3C).opacity(0.12), lineWidth: 1)
    }

    // MARK: Book asset (SF Symbol, subtle)

    @ViewBuilder
    private var bookAsset: some View {
        Image(systemName: "book.closed.fill")
            .font(.system(size: 72, weight: .thin))
            .foregroundStyle(Color(hex: 0x8C3E36).opacity(0.18))
            .rotationEffect(.degrees(-8))
            .offset(x: 8, y: 12)
            .allowsHitTesting(false)
            .clipped()
    }
}

// MARK: - Preview

#Preview("Latest Story") {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()
        HStack {
            LatestStoryTile(
                title: "The Softly Luteal Issue",
                snippet: "Your body kept asking for rest.",
                dateLabel: "MAR 2026 · CYCLE 6",
                isNew: true,
                onTap: {}
            )
            .frame(width: 180)
            Spacer()
        }
        .padding(20)
    }
}
