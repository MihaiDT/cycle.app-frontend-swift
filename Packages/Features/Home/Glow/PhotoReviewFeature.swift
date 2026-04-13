import ComposableArchitecture
import SwiftUI

// MARK: - Photo Review Feature

@Reducer
struct PhotoReviewFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        let imageData: Data
        let thumbnailData: Data
    }

    enum Action: Sendable {
        case submitTapped
        case retakeTapped
        case delegate(Delegate)
        enum Delegate: Sendable {
            case submit(fullSize: Data, thumbnail: Data)
            case retake
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .submitTapped:
                return .send(.delegate(.submit(fullSize: state.imageData, thumbnail: state.thumbnailData)))
            case .retakeTapped:
                return .send(.delegate(.retake))
            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Photo Review View

struct PhotoReviewView: View {
    let store: StoreOf<PhotoReviewFeature>

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                if let uiImage = UIImage(data: store.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                VStack(spacing: 16) {
                    Text("Aria will check if it matches")
                        .font(.custom("Raleway-Medium", size: 15))
                        .foregroundStyle(.white.opacity(0.7))

                    HStack(spacing: 16) {
                        Button {
                            store.send(.retakeTapped)
                        } label: {
                            Text("Retake")
                                .font(.custom("Raleway-Medium", size: 16))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.white.opacity(0.15))
                                }
                        }
                        .buttonStyle(.plain)

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            store.send(.submitTapped)
                        } label: {
                            Text("Submit")
                                .font(.custom("Raleway-SemiBold", size: 16))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(DesignColors.accentWarm)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
                .background(.black.opacity(0.8))
            }
        }
    }
}
