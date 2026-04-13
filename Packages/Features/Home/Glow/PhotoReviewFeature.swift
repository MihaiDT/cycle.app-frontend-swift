import ComposableArchitecture
import SwiftUI

// MARK: - Photo Review Feature

@Reducer
public struct PhotoReviewFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public let imageData: Data
        public let thumbnailData: Data
        public init(imageData: Data, thumbnailData: Data) {
            self.imageData = imageData
            self.thumbnailData = thumbnailData
        }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case submitTapped
        case retakeTapped
        case delegate(Delegate)
        public enum Delegate: Sendable {
            case submit(fullSize: Data, thumbnail: Data)
            case retake
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
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
