import ComposableArchitecture
import SwiftUI

// MARK: - Profile View
//
// Pushed onto the Me tab's NavigationStack. Shell mirrors the other
// pushed destinations in the app (Body Patterns, Cycle Stats): warm
// AppleHealthBackground edge-to-edge, native nav-bar back chevron via
// `.toolbarBackground(.hidden)`, 14pt screen gutter with 24pt rhythm
// between cards.

public struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>
    let onDismiss: () -> Void

    public init(store: StoreOf<ProfileFeature>, onDismiss: @escaping () -> Void) {
        self.store = store
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            navigationStack

            if isSavingAnywhere {
                savingOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isSavingAnywhere)
    }

    private var isSavingAnywhere: Bool {
        store.editCycle?.cycleLengthEditor?.isSaving == true
            || store.editCycle?.periodLengthEditor?.isSaving == true
    }

    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()

            VStack(spacing: AppLayout.spacingM) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(DesignColors.text)
                    .controlSize(.large)

                Text("Saving")
                    .font(.raleway("SemiBold", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.text)
            }
            .padding(.horizontal, AppLayout.spacingL)
            .padding(.vertical, AppLayout.spacingL)
            .frame(minWidth: 140)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL)
                    .fill(.ultraThinMaterial)
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Saving")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var navigationStack: some View {
        NavigationStack {
            ZStack {
                AppleHealthBackground()
                    .ignoresSafeArea()

                scrollContent
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        onDismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(DesignColors.text)
                    }
                    .glassToolbar()
                    .accessibilityLabel("Back")
                }
                ToolbarItem(placement: .principal) {
                    Text("Profile")
                        .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                        .foregroundStyle(DesignColors.text)
                }
            }
            .navigationDestination(
                item: $store.scope(state: \.edit, action: \.edit)
            ) { editStore in
                EditProfileView(store: editStore)
            }
            .navigationDestination(
                item: $store.scope(state: \.editCycle, action: \.editCycle)
            ) { editCycleStore in
                EditCycleView(store: editCycleStore)
            }
            .navigationDestination(isPresented: notificationsScreenBinding) {
                notificationsScreen
            }
            .navigationDestination(isPresented: trackingPreferencesScreenBinding) {
                TrackingPersonalizationView()
            }
            .navigationDestination(isPresented: settingsScreenBinding) {
                SettingsView()
            }
        }
        .tint(DesignColors.text)
        .onAppear { store.send(.onAppear) }
        .sheet(isPresented: reminderSheetBinding) { reminderSheet }
        .confirmationDialog(
            "Delete your account?",
            isPresented: deleteDialogBinding,
            titleVisibility: .visible,
            actions: { deleteDialogActions },
            message: { deleteDialogMessage }
        )
    }

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: AppLayout.spacingL) {
                identityHeader
                detailsCard
                healthCard
                notificationsCard
                privacyCard
                accountCard
                aboutCard
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.top, AppLayout.spacingS)
            .padding(.bottom, AppLayout.spacingXL)
        }
        .scrollIndicators(.hidden)
    }

    private var identityHeader: some View {
        ProfileIdentityHeader(
            name: store.displayName,
            email: store.displayEmail,
            memberSince: store.memberSinceDate,
            onEdit: { store.send(.editTapped) }
        )
    }

    private var detailsCard: some View {
        section(title: "Your details") {
            ProfileDetailsCard(
                birthDate: store.snapshot?.birthDate,
                birthTime: store.snapshot?.birthTime,
                birthPlace: store.snapshot?.birthPlace,
                onEdit: { store.send(.editTapped) }
            )
        }
    }

    private var healthCard: some View {
        section(title: "Health profile") {
            ProfileHealthCard(
                onEdit: { store.send(.cycleDataTapped) }
            )
        }
    }

    private var notificationsCard: some View {
        section(title: "In-app preferences") {
            ProfileAppPreferencesCard(
                onTrackingTap: { store.send(.trackingPreferencesTapped) },
                onRemindersTap: { store.send(.remindersPreferencesTapped) },
                onSettingsTap: { store.send(.settingsPreferencesTapped) }
            )
        }
    }

    private var privacyCard: some View {
        section(title: "Privacy & data") {
            ProfilePrivacyCard(
                probe: store.healthKitProbe,
                onHealthKitTap: { store.send(.healthKitRowTapped) }
            )
        }
    }

    private var accountCard: some View {
        section(title: "Account") {
            ProfileAccountCard(
                onLogout: { store.send(.logoutTapped) },
                onDeleteTapped: { store.send(.deleteAccountTapped) },
                onResetCycleData: { store.send(.resetCycleDataTapped) }
            )
        }
    }

    private var aboutCard: some View {
        section(title: "About") {
            ProfileAboutCard(
                onOpenURL: { store.send(.openURL($0)) }
            )
        }
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppLayout.spacingS) {
            Text(title.uppercased())
                .font(AppTypography.cardEyebrow)
                .tracking(AppTypography.cardEyebrowTracking)
                .foregroundStyle(DesignColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppLayout.spacingXS)

            content()
        }
    }

    private var reminderSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isReminderTimePickerVisible },
            set: { if !$0 { store.send(.reminderTimePickerDismissed) } }
        )
    }

    private var reminderSheet: some View {
        DatePickerSheet(
            selection: Binding(
                get: { store.reminderTime },
                set: { store.send(.reminderTimeChanged($0)) }
            ),
            isPresented: reminderSheetBinding,
            title: "Reminder time",
            displayedComponents: .hourAndMinute
        )
    }

    private var notificationsScreenBinding: Binding<Bool> {
        Binding(
            get: { store.isNotificationsSheetVisible },
            set: { if !$0 { store.send(.notificationsSheetDismissed) } }
        )
    }

    private var trackingPreferencesScreenBinding: Binding<Bool> {
        Binding(
            get: { store.isTrackingPreferencesVisible },
            set: { if !$0 { store.send(.trackingPreferencesDismissed) } }
        )
    }

    private var settingsScreenBinding: Binding<Bool> {
        Binding(
            get: { store.isSettingsVisible },
            set: { if !$0 { store.send(.settingsDismissed) } }
        )
    }

    private var notificationsScreen: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            ScrollView {
                ProfileNotificationsCard(
                    isOn: store.notificationsEnabled,
                    reminderTime: store.reminderTime,
                    onToggle: { store.send(.notificationsToggled($0)) },
                    onReminderRowTap: { store.send(.reminderRowTapped) }
                )
                .padding(.horizontal, AppLayout.screenHorizontal)
                .padding(.top, AppLayout.spacingS)
                .padding(.bottom, AppLayout.spacingXL)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Reminders & notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            backToolbarItem(action: { store.send(.notificationsSheetDismissed) })
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { store.isConfirmingDelete },
            set: { store.send(.deleteConfirmationChanged($0)) }
        )
    }

    @ViewBuilder
    private var deleteDialogActions: some View {
        Button("Delete account", role: .destructive) {
            store.send(.deleteConfirmed)
        }
        Button("Cancel", role: .cancel) {}
    }

    private var deleteDialogMessage: some View {
        Text("This wipes every cycle, symptom, and check-in on this device. You can't undo this.")
    }

}