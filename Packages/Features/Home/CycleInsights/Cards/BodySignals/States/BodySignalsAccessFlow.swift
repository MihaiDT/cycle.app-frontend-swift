import SwiftUI

// MARK: - Body Signals Access Flow
//
// Two-screen wizard surfaced from the BodySignals card. Both entry
// modes (`.prompt` and `.denied`) land on Screen 1 — the explainer
// is information the user wants regardless of their prior decision
// ("how the link works", "your data, your call"). Tapping "Sync
// with Apple" fires `requestAuthorization()` in the background and
// **routes the flow synchronously** based on the current `permission`:
//
//   - `.granted` / `.partial` → dismiss; the user has approved at
//     some prior point and any new prompt iOS fires can't change
//     that.
//   - everything else (`.denied` / `.unavailable` / `.undetermined`
//     / `nil`) → slide to Screen 2 (Settings instructions).
//
// We do **not** wait for the post-prompt re-load. Waiting introduced
// a visible pause on every silent-skip path ("I tapped sync, nothing
// happened"). When iOS does decide to show the native prompt, it
// layers on top of Screen 2 — Screen 2 is a safe landing either
// way: granted users see fresh data the moment they close the
// sheet, denied users see the Settings instructions they need.
//
// Tearing down the sheet synchronously when firing the prompt
// cancels iOS's presentation — don't try to "save a tap" by pre-
// dismissing.
//
// We deliberately avoid `NavigationStack`: profiling showed the
// stack's first-init cost added a perceptible hitch on sheet
// present, and the flow has exactly two screens with no dynamic
// destinations, so a single state-driven view switch is cheaper.
// The two screens crossfade via paired opacity bindings inside a
// `ZStack` — the slide-based asymmetric transition we had earlier
// left a one-frame empty backdrop in the middle of the swap (the
// leaving view was unmounted before the incoming one finished its
// entrance), which read as "the screen flickered blank". Crossfade
// keeps both screens mounted and trades opacity in lockstep, with
// `allowsHitTesting` routing taps to whichever side is visible.
//
// The chevron in the top-left always closes the sheet (the two
// screens are reached forward-only — no back-stack between them).

public enum BodySignalsAccessFlowMode: String, Identifiable, Equatable, Sendable {
    case prompt
    case denied

    public var id: String { rawValue }
}

public struct BodySignalsAccessFlow: View {
    public let mode: BodySignalsAccessFlowMode
    public let onSync: () -> Void
    /// The host card's current permission read-out. Read once at
    /// "Sync with Apple" tap time — we route synchronously and do
    /// not wait for the post-prompt load to update this value.
    public let permission: BodySignalsSnapshot.PermissionState?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showingManage: Bool

    public init(
        mode: BodySignalsAccessFlowMode,
        onSync: @escaping () -> Void,
        permission: BodySignalsSnapshot.PermissionState?
    ) {
        self.mode = mode
        self.onSync = onSync
        self.permission = permission
        // Both entry modes start on the explainer (Screen 1). Even
        // when the user has previously refused, they want to read the
        // "how the link works" + "your data, your call" pitch before
        // committing to a Settings detour. Tapping "Sync with Apple"
        // from there will silently no-op if iOS has already cached a
        // decision; `handlePermissionUpdate` then slides to the
        // Settings screen.
        _showingManage = State(initialValue: false)
    }

    public var body: some View {
        ZStack {
            AppleHealthBackground()

            // Both screens stay mounted in a ZStack and crossfade
            // via opacity. The slide-based asymmetric transition we
            // had before left a single frame of empty backdrop in
            // the middle of the swap (the leaving view was already
            // gone before the incoming one was rendered) — visually
            // read as "the screen flickered blank". Opacity-paired
            // mounts give us a clean crossfade with no empty
            // moment, and `allowsHitTesting` keeps taps routed to
            // whichever screen is currently visible.
            connectScreen
                .opacity(showingManage ? 0 : 1)
                .allowsHitTesting(!showingManage)

            manageScreen
                .opacity(showingManage ? 1 : 0)
                .allowsHitTesting(showingManage)
        }
        .animation(.easeInOut(duration: 0.28), value: showingManage)
        .overlay(alignment: .topLeading) {
            backButton
                .padding(.horizontal, AppLayout.horizontalPadding)
                .padding(.top, 12)
        }
    }

    /// Routes immediately after the user taps "Sync with Apple".
    /// `requestAuthorization()` runs in the background; we don't
    /// wait for it. Branching is on `permission` *as it stands now*:
    ///
    ///   - `.granted` / `.partial` → close the sheet; the user has
    ///     already approved at some point and any new prompt iOS
    ///     fires won't change that.
    ///   - everything else → slide to Screen 2 (Settings). When iOS
    ///     does show the native prompt on top, Screen 2 is a safe
    ///     landing — the host card picks up the new permission via
    ///     its own load and re-renders independently.
    private func routeAfterSync() {
        switch permission {
        case .granted, .partial:
            dismiss()
        case .denied, .unavailable, .undetermined, .none:
            // Plain assignment — the parent `ZStack`'s
            // `.animation(value: showingManage)` carries the
            // crossfade. Wrapping in an extra `withAnimation` here
            // would double-trigger and visibly "stutter" the swap.
            showingManage = true
        }
    }

    // MARK: - Back / close button

    private var backButton: some View {
        // Each entry mode is its own screen — no linear back-stack
        // between them, so the chevron is always "close the sheet".
        GlassBackButton {
            dismiss()
        }
        .frame(width: 36, height: 36)
        .accessibilityLabel("Close")
    }

    // MARK: - Screen 1 — Connect explainer

    private var connectScreen: some View {
        screenScaffold(footer: {
            HeroGlassCapsuleButton("Sync with Apple", layout: .large) {
                // Fire the native HealthKit prompt and stay on this
                // sheet. iOS layers the system dialog on top; the
                // user decides; the host re-loads body signals; the
                // outcome flows back through the `permission` prop.
                //
                // Two completion paths:
                //   1. The `isLoading` true→false edge fires when the
                //      load effect finishes — observed in the
                //      `.onChange` below.
                //   2. A guarded fallback Task (~1.2s) backstops the
                //      observation: when iOS silently skips the
                //      prompt the request resolves so fast that
                //      SwiftUI may not surface the loading edge to
                //      this view at all (the sheet body re-evaluates
                //      with `isLoading` already back to `false`),
                //      and the user would otherwise be stuck on
                //      Screen 1 with no feedback.
                //
                // We do **not** call `dismiss()` here. Tearing down
                // the presenting sheet while the native prompt is
                // being scheduled cancels iOS's presentation.
                onSync()
                // Instant transition: route on whatever `permission`
                // is at tap time. If iOS does end up showing the
                // native prompt, it layers on top of Screen 2 and
                // the host card will catch up to whatever the user
                // picks via its own data load — Screen 2 is a safe
                // landing either way (granted users see their data
                // when they close the sheet anyway).
                routeAfterSync()
            }
        }) {
            VStack(alignment: .center, spacing: 22) {
                iconBadge

                Text("Connect cycle.app with Apple Health")
                    .font(.raleway("Bold", size: 24, relativeTo: .title2))
                    .tracking(-0.4)
                    .foregroundStyle(DesignColors.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 22) {
                    section(
                        heading: "How the link works",
                        body: "Apple Health asks which signals you'd like to share. cycle.app reads wrist temperature, HRV, and resting heart rate from today onward – nothing retroactive, only what you opt in to."
                    )
                    section(
                        heading: "Your data, your call",
                        body: "What you share stays yours. You can adjust your selection any time inside Apple Health settings, and cycle.app only ever reads the signals you've explicitly enabled."
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var iconBadge: some View {
        Image("HealthIcon", bundle: .main)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 48, height: 48)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 6)
            )
            .accessibilityHidden(true)
    }

    private func section(heading: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading)
                .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text)
            Text(body)
                .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Screen 2 — Manage instructions

    private var manageScreen: some View {
        screenScaffold(footer: {
            HeroGlassCapsuleButton("Open cycle.app Settings", layout: .large) {
                openSettings()
                dismiss()
            }
        }) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Apple Health")
                    .font(.raleway("Bold", size: 26, relativeTo: .title))
                    .tracking(-0.4)
                    .foregroundStyle(DesignColors.text)
                    .padding(.top, 4)

                Text("We'll drop you straight into cycle.app's settings page. From there, two taps:")
                    .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 18) {
                    step(
                        systemIcon: "heart.fill",
                        text: "Tap Health.",
                        iconTint: DesignColors.calendarPeriodGlyph
                    )
                    step(systemIcon: "switch.2", text: "Toggle Wrist Temperature, HRV, and Resting Heart Rate.")
                }
                .padding(.top, 4)
            }
        }
    }

    private func step(
        systemIcon: String,
        text: String,
        iconTint: Color = DesignColors.text
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: systemIcon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(iconTint)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(DesignColors.text.opacity(0.10), lineWidth: 0.6)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )

            Text(text)
                .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.text.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Scaffold

    @ViewBuilder
    private func screenScaffold<Content: View, Footer: View>(
        @ViewBuilder footer: () -> Footer,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Reserve room for the back chevron overlay plus breathing
            // space so headings on Screen 2 don't crowd the button.
            Color.clear.frame(height: 64)

            ScrollView {
                content()
                    .padding(.horizontal, AppLayout.horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            }

            footer()
                .padding(.horizontal, AppLayout.horizontalPadding)
                .padding(.bottom, 24)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openSettings() {
        // `app-settings:` opens iOS Settings directly on cycle.app's
        // page — the "Health" sub-row sits right there. iOS doesn't
        // expose a public deep link to the per-type HealthKit toggle
        // page, so this is as close as we can land the user before
        // they have to tap once more themselves.
        guard let url = URL(string: "app-settings:") else { return }
        openURL(url)
    }
}
