import SwiftUI

// MARK: - App Lock View
//
// Full-screen overlay shown while the app is locked behind Face
// ID. Auto-prompts on first appear so the unlock attempt happens
// without a manual tap, and exposes a retry button if the user
// cancels the system prompt.
//
// Styled to match the warm peach AppleHealthBackground so the
// transition into the unlocked app feels continuous rather than
// dropping the user into a stark system modal.

struct AppLockView: View {
    @ObservedObject var controller: BiometricLockController
    @State private var didAutoPrompt = false
    @State private var attemptingUnlock = false

    var body: some View {
        ZStack {
            // Solid base — AppleHealthBackground is a translucent
            // gradient (peach 0.38 → white) so without an opaque
            // backdrop the app's data leaks through the lock view.
            // The point of the gate is that the user (or anyone
            // peeking) can't see anything until they authenticate.
            DesignColors.background
                .ignoresSafeArea()

            AppleHealthBackground()
                .ignoresSafeArea()

            VStack(spacing: AppLayout.spacingL) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(DesignColors.accentWarm.opacity(0.14))
                        .frame(width: 132, height: 132)

                    Image(systemName: "faceid")
                        .font(.system(size: 56, weight: .regular))
                        .foregroundStyle(DesignColors.accentWarm)
                }

                VStack(spacing: AppLayout.spacingS) {
                    Text("Locked")
                        .font(AppTypography.displayHeader)
                        .foregroundStyle(DesignColors.text)

                    Text("Authenticate with Face ID or your device passcode to continue.")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(DesignColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, AppLayout.spacingL)
                }

                Spacer()

                WarmCapsuleButton(
                    attemptingUnlock ? "Authenticating…" : "Unlock",
                    prominence: .primary,
                    isFullWidth: true,
                    action: { Task { await unlock() } }
                )
                .disabled(attemptingUnlock)
                .padding(.horizontal, AppLayout.screenHorizontal)
                .padding(.bottom, AppLayout.spacingL)
            }
        }
        .task {
            // Only auto-prompt on first appear so we don't loop
            // back into the system prompt if the user dismisses it.
            guard !didAutoPrompt else { return }
            didAutoPrompt = true
            await unlock()
        }
    }

    private func unlock() async {
        guard !attemptingUnlock else { return }
        attemptingUnlock = true
        defer { attemptingUnlock = false }
        await controller.authenticate(reason: "Unlock cycle.app to continue.")
    }
}
