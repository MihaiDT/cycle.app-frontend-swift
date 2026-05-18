import ComposableArchitecture
import Foundation
import SwiftUI
import UIKit

// MARK: - Profile Feature
//
// Pushed onto the Me tab's NavigationStack when the user taps the
// header avatar. Owns identity / birth data / notifications / privacy /
// account sections. All data is on-device — reads and writes go through
// `userProfileLocal`. Logout / delete-account bubble up via
// `delegate(.didLogout)` to the existing handler on HomeFeature.

@Reducer
public struct ProfileFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        /// The signed-in user as known to HomeFeature. Mostly used as
        /// a fallback for `email` and `createdAt` until the local-first
        /// snapshot loads (and as the only source of email — the
        /// snapshot doesn't carry one).
        public var user: User?

        /// On-device profile snapshot. Nil while loading or if the user
        /// has not finished onboarding.
        public var snapshot: UserProfileSnapshot?

        /// HealthKit authorization probe — drives the Privacy card row.
        public var healthKitProbe: BodySignalsAuthProbe = .canProceed

        /// Whether the system-level notification permission is granted.
        /// Used to detect "user toggled in-app but iOS permission was
        /// previously denied" and surface the Settings deep-link.
        public var notificationsAuthorized: Bool = false

        public var isConfirmingDelete: Bool = false
        public var isReminderTimePickerVisible: Bool = false
        public var isNotificationsSheetVisible: Bool = false
        public var isTrackingPreferencesVisible: Bool = false
        public var isSettingsVisible: Bool = false

        @Presents public var edit: EditProfileFeature.State?
        @Presents public var editCycle: EditCycleFeature.State?

        public var menstrualStatus: MenstrualStatusResponse?

        public init(user: User? = nil) {
            self.user = user
        }

        // MARK: Derived

        public var notificationsEnabled: Bool {
            snapshot?.notificationsEnabled ?? false
        }

        public var reminderHour: Int { snapshot?.dailyCheckinHour ?? 20 }
        public var reminderMinute: Int { snapshot?.dailyCheckinMinute ?? 0 }

        public var reminderTime: Date {
            var comps = DateComponents()
            comps.hour = reminderHour
            comps.minute = reminderMinute
            return Calendar.current.date(from: comps) ?? .now
        }

        public var displayName: String {
            snapshot?.userName ?? user?.fullName ?? "—"
        }

        public var displayEmail: String? {
            guard let email = user?.email, !email.isEmpty else { return nil }
            return email
        }

        public var memberSinceDate: Date {
            snapshot?.createdAt ?? user?.createdAt ?? .now
        }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case onAppear
        case profileLoaded(UserProfileSnapshot?)
        case healthKitProbeLoaded(BodySignalsAuthProbe)
        case notificationsAuthorizationLoaded(Bool)

        case editTapped
        case cycleDataTapped
        case notificationsToggled(Bool)
        case reminderRowTapped
        case reminderTimePickerDismissed
        case reminderTimeChanged(Date)
        case trackingPreferencesTapped
        case trackingPreferencesDismissed
        case remindersPreferencesTapped
        case settingsPreferencesTapped
        case settingsDismissed
        case notificationsSheetDismissed
        case healthKitRowTapped
        case openSettingsTapped

        case logoutTapped
        case resetCycleDataTapped
        case cycleDataReset
        case deleteAccountTapped
        case deleteConfirmationChanged(Bool)
        case deleteConfirmed
        case profileDeleted

        case openURL(URL)

        case edit(PresentationAction<EditProfileFeature.Action>)
        case editCycle(PresentationAction<EditCycleFeature.Action>)
        case menstrualStatusLoaded(MenstrualStatusResponse?)
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case didLogout
            case showCycleEditor
            case cycleDataChanged
        }
    }

    @Dependency(\.userProfileLocal) var userProfileLocal
    @Dependency(\.localNotifications) var localNotifications
    @Dependency(\.healthKitLocal) var healthKitLocal
    @Dependency(\.menstrualLocal) var menstrualLocal

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding, .delegate:
                return .none

            case .onAppear:
                return .merge(
                    .run { [userProfileLocal] send in
                        let snapshot = try? await userProfileLocal.getProfile()
                        await send(.profileLoaded(snapshot))
                    },
                    .run { [healthKitLocal] send in
                        let probe = healthKitLocal.authorizationProbe()
                        await send(.healthKitProbeLoaded(probe))
                    },
                    .run { [localNotifications] send in
                        let granted = await localNotifications.isAuthorized()
                        await send(.notificationsAuthorizationLoaded(granted))
                    },
                    .run { [menstrualLocal] send in
                        let status = try? await menstrualLocal.getStatus()
                        await send(.menstrualStatusLoaded(status))
                    }
                )

            case let .menstrualStatusLoaded(status):
                state.menstrualStatus = status
                return .none

            case let .profileLoaded(snapshot):
                state.snapshot = snapshot
                return .none

            case let .healthKitProbeLoaded(probe):
                state.healthKitProbe = probe
                return .none

            case let .notificationsAuthorizationLoaded(granted):
                state.notificationsAuthorized = granted
                return .none

            case .editTapped:
                guard let snapshot = state.snapshot else { return .none }
                state.edit = EditProfileFeature.State(snapshot: snapshot)
                return .none

            case .cycleDataTapped:
                state.editCycle = EditCycleFeature.State()
                return .none

            case .editCycle(.presented(.delegate(.didSave))):
                // Sub-editor's parent (EditCycleFeature) bubbles
                // didSave whenever cycle/period length actually
                // changed in storage. Forward to whoever owns Profile
                // so they can refresh dependent UI (the Calendar).
                return .send(.delegate(.cycleDataChanged))

            case .editCycle:
                return .none

            case let .notificationsToggled(isOn):
                guard var snapshot = state.snapshot else { return .none }
                snapshot.notificationsEnabled = isOn
                state.snapshot = snapshot
                let hour = snapshot.dailyCheckinHour
                let minute = snapshot.dailyCheckinMinute
                let snapshotForSave = snapshot
                return .run { [userProfileLocal, localNotifications] send in
                    try? await userProfileLocal.saveProfile(snapshotForSave)
                    if isOn {
                        let granted = (try? await localNotifications.requestAuthorization()) ?? false
                        await send(.notificationsAuthorizationLoaded(granted))
                        if granted {
                            try? await localNotifications.scheduleDailyReminder(hour, minute)
                        }
                    } else {
                        await localNotifications.cancelAll()
                    }
                }

            case .reminderRowTapped:
                state.isReminderTimePickerVisible = true
                return .none

            case .reminderTimePickerDismissed:
                state.isReminderTimePickerVisible = false
                return .none

            case .trackingPreferencesTapped:
                state.isTrackingPreferencesVisible = true
                return .none

            case .trackingPreferencesDismissed:
                state.isTrackingPreferencesVisible = false
                return .none

            case .settingsPreferencesTapped:
                state.isSettingsVisible = true
                return .none

            case .settingsDismissed:
                state.isSettingsVisible = false
                return .none

            case .remindersPreferencesTapped:
                state.isNotificationsSheetVisible = true
                return .none

            case .notificationsSheetDismissed:
                state.isNotificationsSheetVisible = false
                return .none

            case let .reminderTimeChanged(date):
                guard var snapshot = state.snapshot else { return .none }
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                let hour = comps.hour ?? 20
                let minute = comps.minute ?? 0
                snapshot.dailyCheckinHour = hour
                snapshot.dailyCheckinMinute = minute
                state.snapshot = snapshot
                let snapshotForSave = snapshot
                let shouldReschedule = snapshot.notificationsEnabled
                return .run { [userProfileLocal, localNotifications] _ in
                    try? await userProfileLocal.saveProfile(snapshotForSave)
                    if shouldReschedule {
                        try? await localNotifications.scheduleDailyReminder(hour, minute)
                    }
                }

            case .healthKitRowTapped:
                switch state.healthKitProbe {
                case .unavailable:
                    return .none
                case .needsPrompt:
                    return .run { [healthKitLocal] send in
                        try? await healthKitLocal.requestAuthorization()
                        let probe = healthKitLocal.authorizationProbe()
                        await send(.healthKitProbeLoaded(probe))
                    }
                case .canProceed:
                    return .send(.openSettingsTapped)
                }

            case .openSettingsTapped:
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return .none }
                return .send(.openURL(url))

            case let .openURL(url):
                return .run { _ in
                    await MainActor.run {
                        UIApplication.shared.open(url)
                    }
                }

            case .logoutTapped:
                return .send(.delegate(.didLogout))

            case .resetCycleDataTapped:
                return .run { [menstrualLocal] send in
                    try? await menstrualLocal.resetAllCycleData()
                    try? await menstrualLocal.generatePrediction()
                    await send(.cycleDataReset)
                }

            case .cycleDataReset:
                // Refresh the menu's cached summary + bubble up so the
                // calendar reloads.
                return .send(.delegate(.cycleDataChanged))

            case .deleteAccountTapped:
                state.isConfirmingDelete = true
                return .none

            case let .deleteConfirmationChanged(isPresented):
                state.isConfirmingDelete = isPresented
                return .none

            case .deleteConfirmed:
                state.isConfirmingDelete = false
                return .run { [userProfileLocal] send in
                    try? await userProfileLocal.deleteProfile()
                    await send(.profileDeleted)
                }

            case .profileDeleted:
                return .send(.delegate(.didLogout))

            case let .edit(.presented(.delegate(.didSave(snapshot)))):
                state.snapshot = snapshot
                state.edit = nil
                return .none

            case .edit:
                return .none
            }
        }
        .ifLet(\.$edit, action: \.edit) {
            EditProfileFeature()
        }
        .ifLet(\.$editCycle, action: \.editCycle) {
            EditCycleFeature()
        }
    }
}