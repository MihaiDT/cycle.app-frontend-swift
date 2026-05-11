import SwiftUI

/// Trailing utility bar pinned to the bottom of the symptom
/// sheet. Hosts the inline search field and the settings entry
/// point inside a **single** glass capsule — they're peers in
/// the same control rather than two disconnected discs sitting
/// next to each other.
///
/// Layout intent:
///   * Leading: magnifying-glass glyph
///   * Centre: real `TextField` bound to
///     `CalendarFeature.State.symptomSearchText` with a
///     dynamic placeholder ("Search 56 symptoms",
///     "Search Mood", etc.) so the empty state communicates
///     scope rather than an iOS-default `Search…` label.
///   * Right of the field: clear button (× chip) — only while
///     the text is non-empty.
///   * Trailing: thin divider then a 32pt gear button. Tapping
///     it opens the settings sheet without stealing focus
///     from the field.
struct SymptomBottomBar: View {
    @Binding var searchText: String
    /// Caller-driven copy for the empty field. Lets the host
    /// describe the search scope (count of symptoms, current
    /// category) without this view having to know about the
    /// catalogue. Falls back to a sensible default.
    var placeholder: String = "Search symptoms"
    let onOpenSettings: () -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignColors.textSecondary)

            TextField(placeholder, text: $searchText)
                .font(.raleway("Medium", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text)
                .tint(DesignColors.accentWarm)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .frame(maxWidth: .infinity)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignColors.textSecondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }

            // Vertical hairline so the gear reads as a sibling
            // accessory of the search field rather than part of
            // its content. Bumped from `accentWarm@18%` to
            // `@30%` after audit pass — the previous opacity
            // was practically invisible on the glass capsule.
            Rectangle()
                .fill(DesignColors.accentWarm.opacity(0.30))
                .frame(width: 1, height: 22)

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                isSearchFocused = false
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DesignColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Symptom settings")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .contentShape(Capsule())
        // `interactive: false` — the bar already has explicit
        // input behaviour (`onTapGesture` to focus the search +
        // a settings Button). Default `true` adds iOS 26's
        // glass press shader on top, which raced both for hit
        // testing and produced `IOSurfaceClientSetSurfaceNotify`
        // console errors plus tap drops on the symptom sheet.
        .nativeGlass(in: Capsule(), interactive: false)
        .animation(.easeInOut(duration: 0.18), value: searchText.isEmpty)
        .onTapGesture {
            isSearchFocused = true
        }
    }
}
