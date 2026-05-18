import ComposableArchitecture
import Foundation
import SwiftUI

// MARK: - Edit Profile Feature
//
// Pushed from Profile. Edits the four identity-shaped fields (name,
// birth date, birth time, birth place). On Save, builds a new snapshot
// that preserves every field the user didn't touch and persists via
// `userProfileLocal.saveProfile`, then bubbles the updated snapshot
// back to ProfileFeature so the parent header refreshes without a
// re-fetch.

@Reducer
public struct EditProfileFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        /// The full original snapshot — kept around so Save can preserve
        /// every field that's not exposed in this form (notifications,
        /// onboarding answers, consent flags, etc.).
        public var original: UserProfileSnapshot

        public var userName: String
        public var birthDate: Date
        public var birthTime: Date
        public var birthPlace: String
        public var selectedBirthPlace: PlacesAutocompleteTextField.SelectedPlace?

        public var isSaving: Bool = false
        public var isDatePickerVisible: Bool = false
        public var isTimePickerVisible: Bool = false

        public init(snapshot: UserProfileSnapshot) {
            self.original = snapshot
            self.userName = snapshot.userName
            self.birthDate = snapshot.birthDate ?? .now
            self.birthTime = snapshot.birthTime ?? .now
            self.birthPlace = snapshot.birthPlace ?? ""
            if let name = snapshot.birthPlace,
               let lat = snapshot.birthPlaceLat,
               let lng = snapshot.birthPlaceLng {
                self.selectedBirthPlace = PlacesAutocompleteTextField.SelectedPlace(
                    placeId: "",
                    name: name,
                    formattedAddress: name,
                    latitude: lat,
                    longitude: lng,
                    timezone: snapshot.birthPlaceTimezone
                )
            }
        }

        public var canSave: Bool {
            !userName.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
        }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case datePickerShown
        case datePickerDismissed
        case timePickerShown
        case timePickerDismissed
        case saveTapped
        case saveCompleted(UserProfileSnapshot)
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case didSave(UserProfileSnapshot)
        }
    }

    @Dependency(\.userProfileLocal) var userProfileLocal

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding, .delegate:
                return .none

            case .datePickerShown:
                state.isDatePickerVisible = true
                return .none
            case .datePickerDismissed:
                state.isDatePickerVisible = false
                return .none
            case .timePickerShown:
                state.isTimePickerVisible = true
                return .none
            case .timePickerDismissed:
                state.isTimePickerVisible = false
                return .none

            case .saveTapped:
                guard state.canSave else { return .none }
                state.isSaving = true
                var snapshot = state.original
                snapshot.userName = state.userName.trimmingCharacters(in: .whitespaces)
                snapshot.birthDate = state.birthDate
                snapshot.birthTime = state.birthTime
                if let place = state.selectedBirthPlace {
                    snapshot.birthPlace = place.name
                    snapshot.birthPlaceLat = place.latitude
                    snapshot.birthPlaceLng = place.longitude
                    snapshot.birthPlaceTimezone = place.timezone
                } else if !state.birthPlace.isEmpty {
                    snapshot.birthPlace = state.birthPlace
                }
                let snapshotForSave = snapshot
                return .run { [userProfileLocal] send in
                    try? await userProfileLocal.saveProfile(snapshotForSave)
                    await send(.saveCompleted(snapshotForSave))
                }

            case let .saveCompleted(snapshot):
                state.isSaving = false
                return .send(.delegate(.didSave(snapshot)))
            }
        }
    }
}