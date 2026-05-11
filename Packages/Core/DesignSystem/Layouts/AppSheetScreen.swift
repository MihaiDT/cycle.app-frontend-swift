import SwiftUI

/// Standard layout container for sheet-style surfaces across
/// the app. One template, one place to change padding /
/// background / chrome — so every sheet (symptom logging,
/// settings, day detail, future sheets) reads identical to
/// every other sheet, and every screen built with it reads as
/// a sibling of `BodyPatternsView` and friends.
///
/// What it owns:
///   * `AppleHealthBackground` — warm peach lens, same as the
///     primary screens. Gives the iOS 26 native-glass discs
///     refraction colour and keeps the app's tonal continuity.
///   * Action row — `AppCloseButton` (leading) and an optional
///     `AppDoneButton` (trailing). Pass `onSave: nil` for
///     read-only sheets (e.g. settings panels).
///   * Title — laid out either as a big editorial header below
///     the action row (`.editorial`, default) or as a compact
///     centered title between the two action buttons
///     (`.inline`). Choose the variant that fits the surface:
///     full feature sheets favour `.editorial`, dense
///     utility sheets favour `.inline`.
///   * `content` — the caller's body.
public struct AppSheetScreen<Content: View>: View {
    /// Where the title lives relative to the action row.
    public enum HeaderLayout: Equatable, Sendable {
        /// Big leading-aligned gradient title below the action
        /// row. Optional eyebrow above it. Mirrors BodyPatterns.
        case editorial
        /// Compact title centered between the close and save
        /// discs on a single row. No eyebrow rendered.
        case inline
    }

    public let title: String
    public let eyebrow: String?
    /// Optional inline title rendered between the close and
    /// save discs on the action row — mirrors the iOS toolbar
    /// nav title used on push screens like `BodyPatternsView`,
    /// so a sheet presented in the same surface family reads
    /// with the same chrome. Pass `nil` (default) to keep the
    /// previous "discs only" action row.
    public let navTitle: String?
    public let headerLayout: HeaderLayout
    public let saveState: AppDoneButton.Phase
    public let canSave: Bool
    public let onClose: () -> Void
    public let onSave: (() -> Void)?
    public let content: () -> Content

    public init(
        title: String,
        eyebrow: String? = nil,
        navTitle: String? = nil,
        headerLayout: HeaderLayout = .editorial,
        saveState: AppDoneButton.Phase = .idle,
        canSave: Bool = true,
        onClose: @escaping () -> Void,
        onSave: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.eyebrow = eyebrow
        self.navTitle = navTitle
        self.headerLayout = headerLayout
        self.saveState = saveState
        self.canSave = canSave
        self.onClose = onClose
        self.onSave = onSave
        self.content = content
    }

    public var body: some View {
        // Wrapping the sheet in a `NavigationStack` so the
        // close + save discs ride the system's nav-bar
        // toolbar — identical layout, padding, and safe-area
        // behaviour to push screens like `BodyPatternsView`.
        // Without this, an in-sheet custom action row sat
        // ~30pt lower than the matching push-screen toolbar
        // and the chrome read as inconsistent across surfaces.
        NavigationStack {
            ZStack(alignment: .top) {
                AppleHealthBackground()

                VStack(spacing: 0) {
                    if headerLayout == .editorial {
                        AppScreenHeader(eyebrow: eyebrow, title: title)
                            .padding(.horizontal, 18)
                    }
                    content()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(navTitle ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                // Plain `Button { Image }` items so iOS 26
                // applies its own native Liquid Glass once —
                // using `AppCloseButton` / `AppDoneButton`
                // here painted their own disc on top, which
                // stacked with the system glass into the
                // "double disc" the user spotted.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DesignColors.text)
                    }
                    .glassToolbar()
                    .accessibilityLabel("Close")
                }
                if let onSave {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            guard canSave, saveState == .idle else { return }
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            onSave()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(
                                    size: 16,
                                    weight: saveState == .success ? .bold : .semibold
                                ))
                                .foregroundStyle(
                                    saveState == .success
                                        ? DesignColors.statusSuccess
                                        : DesignColors.text
                                )
                                .opacity(saveState == .loading ? 0.55 : 1.0)
                                .scaleEffect(saveState == .success ? 1.08 : 1.0)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.75),
                                    value: saveState
                                )
                        }
                        .glassToolbar()
                        .disabled(!canSave || saveState != .idle)
                        .accessibilityLabel(
                            saveState == .success
                                ? "Saved"
                                : (saveState == .loading ? "Saving" : "Done")
                        )
                        .onChange(of: saveState) { _, newPhase in
                            if newPhase == .success {
                                UINotificationFeedbackGenerator()
                                    .notificationOccurred(.success)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Inline header

}
