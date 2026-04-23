import ComposableArchitecture
import SwiftUI

// MARK: - Your Day Feature
//
// Owns the "Your day" section on Home. Loads today's Lens previews via
// `LensPreviewClient` (mock today, real later) and renders them as a
// vertical stack of beautiful, tonal preview cards. Tapping a card
// delegates to the parent which in turn opens Lens.

@Reducer
public struct YourDayFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var previews: [LensPreview] = []
        public var isLoading: Bool = false
        public var hasLoadError: Bool = false

        /// Last `(phase, day)` we fetched for. Used to skip redundant
        /// reloads when the dashboard broadcasts the same phase twice.
        public var currentPhase: CyclePhase?
        public var currentDay: Int?

        public init() {}
    }

    public enum Action: Sendable {
        case loadPreviews(CyclePhase, Int)
        case previewsLoaded([LensPreview])
        case loadFailed
        case retryTapped
        case previewTapped(LensPreview)
        case delegate(Delegate)

        public enum Delegate: Sendable, Equatable {
            case openLens(LensPreview)
        }
    }

    @Dependency(\.lensPreview) var lensPreviewClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .loadPreviews(phase, day):
                // Skip reload if the phase is unchanged and we already
                // have content. Day updates silently so the meta row
                // stays fresh without reshuffling today's previews.
                if state.currentPhase == phase && !state.previews.isEmpty {
                    state.currentDay = day
                    return .none
                }

                state.currentPhase = phase
                state.currentDay = day
                state.isLoading = true
                state.hasLoadError = false

                return .run { [lensPreviewClient] send in
                    do {
                        let previews = try await lensPreviewClient.previews(phase, day)
                        await send(.previewsLoaded(previews))
                    } catch {
                        await send(.loadFailed)
                    }
                }

            case let .previewsLoaded(previews):
                state.previews = previews
                state.isLoading = false
                state.hasLoadError = false
                return .none

            case .loadFailed:
                state.isLoading = false
                state.hasLoadError = true
                return .none

            case .retryTapped:
                guard let phase = state.currentPhase, let day = state.currentDay else {
                    return .none
                }
                // Nil out so `.loadPreviews` doesn't short-circuit.
                state.currentPhase = nil
                state.hasLoadError = false
                return .send(.loadPreviews(phase, day))

            case let .previewTapped(preview):
                return .send(.delegate(.openLens(preview)))

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Your Day View

struct YourDayView: View {
    let store: StoreOf<YourDayFeature>

    /// Tracks the currently-snapped preview so the dot indicator below the
    /// carousel stays in sync with horizontal scrolling. iOS 17+ API.
    @State private var visibleID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Your day") {
                dotsIndicator
            }
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.previews.isEmpty {
            skeleton
                .padding(.horizontal, AppLayout.screenHorizontal)
        } else if store.hasLoadError && store.previews.isEmpty {
            errorState
                .padding(.horizontal, AppLayout.screenHorizontal)
        } else {
            carousel
        }
    }

    // MARK: Carousel

    @ViewBuilder
    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(store.previews.enumerated()), id: \.element.id) { index, preview in
                    LensPreviewCard(
                        preview: preview,
                        variation: index,
                        onOpen: { store.send(.previewTapped(preview)) }
                    )
                    // Card takes full width minus peek — iOS 17+ API
                    // that sizes each child relative to the ScrollView.
                    .containerRelativeFrame(.horizontal) { width, _ in
                        width - (AppLayout.screenHorizontal * 2) - 24
                    }
                    .id(preview.id)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, AppLayout.screenHorizontal)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $visibleID)
        .onAppear {
            if visibleID == nil, let first = store.previews.first {
                visibleID = first.id
            }
        }
        .onChange(of: store.previews) { _, newValue in
            if visibleID == nil, let first = newValue.first {
                visibleID = first.id
            }
        }
    }

    // MARK: Dots

    @ViewBuilder
    private var dotsIndicator: some View {
        if store.previews.count > 1 {
            HStack(spacing: 6) {
                ForEach(store.previews) { preview in
                    let isActive = preview.id == visibleID
                    Capsule()
                        .fill(
                            isActive
                                ? DesignColors.accentWarm
                                : DesignColors.structure.opacity(0.25)
                        )
                        .frame(width: isActive ? 20 : 7, height: 7)
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: visibleID)
                        .onTapGesture {
                            // Tap-to-jump — matches accessibility intent of
                            // the carousel for users who can't easily swipe.
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                visibleID = preview.id
                            }
                        }
                        .accessibilityLabel("Preview \(indexOf(preview) + 1) of \(store.previews.count)")
                        .accessibilityAddTraits(isActive ? [.isSelected] : [.isButton])
                }
            }
        } else {
            EmptyView()
        }
    }

    private func indexOf(_ preview: LensPreview) -> Int {
        store.previews.firstIndex(where: { $0.id == preview.id }) ?? 0
    }

    // MARK: Skeleton

    @ViewBuilder
    private var skeleton: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(DesignColors.skeletonBackground.opacity(0.6))
            .frame(height: 200)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading your day")
    }

    // MARK: Error state

    @ViewBuilder
    private var errorState: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("We couldn't load today's previews")
                    .font(.raleway("Bold", size: 15, relativeTo: .headline))
                    .foregroundStyle(DesignColors.text)
                Text("A quick hiccup. Let's try again.")
                    .font(.raleway("Medium", size: 13, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
            }
            .multilineTextAlignment(.center)

            Button {
                store.send(.retryTapped)
            } label: {
                Text("Try again")
                    .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(DesignColors.accentWarm))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DesignColors.skeletonBackground.opacity(0.5))
        )
    }
}
