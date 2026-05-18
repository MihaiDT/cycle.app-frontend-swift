import SwiftUI

// MARK: - Profile Back Toolbar Item
//
// Shared `chevron.left` topBarLeading button used on every screen
// pushed below Profile (Tracking personalization, Reminders &
// notifications, Settings, Download my data, Data export ready).
//
// Each child screen calls `.navigationBarBackButtonHidden(true)`
// and installs this toolbar item so the back affordance is owned
// by the screen itself instead of relying on the parent stack's
// default chevron — keeps the chrome consistent and lets each
// screen wire its own dismiss/haptic side-effects.

@MainActor
@ToolbarContentBuilder
func backToolbarItem(dismiss: DismissAction) -> some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .foregroundStyle(DesignColors.text)
        }
        .glassToolbar()
        .accessibilityLabel("Back")
    }
}

@MainActor
@ToolbarContentBuilder
func backToolbarItem(action: @escaping () -> Void) -> some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        } label: {
            Image(systemName: "chevron.left")
                .foregroundStyle(DesignColors.text)
        }
        .glassToolbar()
        .accessibilityLabel("Back")
    }
}
