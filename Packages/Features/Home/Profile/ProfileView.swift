import ComposableArchitecture
import SwiftUI

// MARK: - Profile View (Me tab — placeholder)
//
// Real Me screen is being built on another branch. This tab only shows
// a single Reset App action that wipes local data and returns to
// onboarding — useful for starting a clean account during development.

public struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>

    public init(store: StoreOf<ProfileFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: AppLayout.spacingL) {
                Spacer(minLength: 0)

                VStack(spacing: AppLayout.spacingS) {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(DesignColors.textSecondary)
                        .padding(.bottom, AppLayout.spacingS)

                    Text("Reset app")
                        .font(.raleway("Bold", size: 22, relativeTo: .title2))
                        .foregroundStyle(DesignColors.text)

                    Text("Clears your on-device data and returns to the start. Use this when you want to begin a fresh account.")
                        .font(.raleway("Regular", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(role: .destructive, action: { store.send(.resetAppTapped) }) {
                    Text("Reset app")
                        .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                        .frame(maxWidth: .infinity, minHeight: AppLayout.buttonHeight)
                        .background {
                            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM, style: .continuous)
                                .fill(DesignColors.accentWarm.opacity(0.15))
                        }
                        .foregroundStyle(DesignColors.accentWarm)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
        }
        .navigationTitle("Me")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Reset app?",
            isPresented: $store.isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset app", role: .destructive) {
                store.send(.resetConfirmed)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes every cycle, symptom, and check-in on this device. You can't undo this.")
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(
            store: .init(initialState: ProfileFeature.State()) {
                ProfileFeature()
            }
        )
    }
}
