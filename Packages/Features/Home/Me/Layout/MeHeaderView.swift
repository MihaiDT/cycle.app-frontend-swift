import ComposableArchitecture
import SwiftUI

// MARK: - Me Header View
//
// Editorial hero at the top of the ME tab. Pull-quote greeting on
// the left, avatar disc on the right — both on the same horizontal
// row, anchored to the bottom of the header slot so the body sheet
// receives them gracefully. Scrolls inside MeView's ScrollView so
// the native nav-bar scroll-edge blur picks the row up on scroll.
//
// `topSafeAreaInset` is passed down from MeView (captured via a
// root-level GeometryReader) because the ScrollView ignores safe
// area, so a GeometryReader local to this view would report 0 and
// the row would sit under the status bar / Dynamic Island.

private enum MeHeaderMetrics {
    static let horizontalPadding: CGFloat = 22
    static let trailingPadding: CGFloat = 22
    static let bottomBuffer: CGFloat = 50
    static let columnSpacing: CGFloat = 16
    static let quoteRotationInterval: Duration = .seconds(6)
    static let quoteTransitionDuration: Double = 0.9
}

private enum MeHeaderQuotes {
    static let all: [String] = [
        "Listen kindly to your body today.",
        "Move slowly — your rhythm knows.",
        "Soften toward what you feel.",
        "Today asks for tenderness.",
        "Notice. Breathe. Begin again.",
        "Your softness is intelligence.",
    ]
}

public struct MeHeaderView: View {
    @Bindable var store: StoreOf<MeFeature>
    let topSafeAreaInset: CGFloat

    @State private var quoteIndex: Int = 0

    public init(store: StoreOf<MeFeature>, topSafeAreaInset: CGFloat) {
        self.store = store
        self.topSafeAreaInset = topSafeAreaInset
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: topSafeAreaInset + 8)

            HStack(alignment: .top, spacing: MeHeaderMetrics.columnSpacing) {
                greeting

                Spacer(minLength: 0)

                avatarButton
            }
            .padding(.leading, MeHeaderMetrics.horizontalPadding)
            .padding(.trailing, MeHeaderMetrics.trailingPadding)
        }
        .padding(.bottom, MeHeaderMetrics.bottomBuffer)
    }

    private var greeting: some View {
        Text(MeHeaderQuotes.all[quoteIndex])
            .font(.raleway("Bold", size: 32, relativeTo: .largeTitle))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        DesignColors.text,
                        DesignColors.textPrincipal,
                        DesignColors.text.opacity(0.85),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .lineLimit(2, reservesSpace: true)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(quoteIndex)
            .transition(.blurReplace.combined(with: .opacity))
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: MeHeaderMetrics.quoteRotationInterval)
                    guard !Task.isCancelled else { break }
                    withAnimation(.easeInOut(duration: MeHeaderMetrics.quoteTransitionDuration)) {
                        quoteIndex = (quoteIndex + 1) % MeHeaderQuotes.all.count
                    }
                }
            }
    }

    private var avatarButton: some View {
        MeHeaderRoundButton(
            variant: .avatar,
            action: { store.send(.avatarTapped) }
        )
    }
}

#Preview {
    MeHeaderView(
        store: .init(initialState: MeFeature.State()) { MeFeature() },
        topSafeAreaInset: 59
    )
    .frame(height: 280)
    .background(AppleHealthBackground())
}
