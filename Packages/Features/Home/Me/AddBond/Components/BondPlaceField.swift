import SwiftUI

// MARK: - Bond Place Field
//
// Custom places autocomplete tuned for the AddBond flow's editorial
// shell. Visually mirrors `GlassTextField` (the same one used by the
// Name step) so the field reads as part of the same family: centred
// text, capsule with `.ultraThinMaterial` fill, soft gradient rim,
// gentle shadow. No leading mappin icon — the editorial copy above
// already names what's being asked.
//
// The component owns the autocomplete loop (debounce + Places client
// search + selection details) so the call site (`AddBondBirthPlaceView`)
// stays tight. Results drop into a glass card beneath the field; on
// tap, the field commits the place's display name and stows the
// dropdown.

struct BondPlaceField: View {
    @Binding var text: String
    @Binding var selectedPlace: PlacesAutocompleteTextField.SelectedPlace?
    let placeholder: String
    /// Reports focus changes back to the parent — used by
    /// `AddBondBirthPlaceView` to collapse the hero/title the
    /// moment the field is tapped (not when the user starts
    /// typing).
    var onFocusChange: ((Bool) -> Void)? = nil

    @State private var isShowingResults = false
    @State private var searchResults: [PlacesAutocompleteTextField.PlaceResult] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSelectingPlace = false
    @FocusState private var isFocused: Bool

    var body: some View {
        // Field on top, dropdown below — the natural reading
        // order. The parent (`AddBondBirthPlaceView`) hides the
        // hero/title and pins the field high on the screen while
        // the keyboard is up, so the results have plenty of
        // unobscured room directly under the field.
        VStack(spacing: 10) {
            field

            if isShowingResults && !searchResults.isEmpty {
                resultsList
                    .transition(.opacity.combined(with: .offset(y: -6)))
            }
        }
        .animation(.easeOut(duration: 0.22), value: isShowingResults)
        .animation(.easeOut(duration: 0.22), value: searchResults.count)
    }

    // MARK: - Field

    private var field: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                .foregroundColor(DesignColors.text.opacity(0.55))
        )
        .focused($isFocused)
        .font(.raleway("SemiBold", size: 16, relativeTo: .body))
        .foregroundColor(DesignColors.text)
        .multilineTextAlignment(.center)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .padding(.horizontal, 24)
        .frame(minHeight: 57)
        .frame(maxWidth: .infinity)
        .background(fieldSurface)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        .onChange(of: text) { _, newValue in
            handleTextChange(newValue)
        }
        .onChange(of: isFocused) { _, newValue in
            onFocusChange?(newValue)
        }
        .onSubmit {
            isShowingResults = false
        }
    }

    private var fieldSurface: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
    }

    // MARK: - Results

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(searchResults.prefix(5).enumerated()), id: \.element.id) { idx, result in
                if idx > 0 {
                    Rectangle()
                        .fill(DesignColors.divider.opacity(0.4))
                        .frame(height: 0.5)
                        .padding(.horizontal, 18)
                }
                resultRow(result)
            }
        }
        .background(resultsSurface)
        .shadow(color: .black.opacity(0.1), radius: 14, x: 0, y: 6)
    }

    private func resultRow(_ result: PlacesAutocompleteTextField.PlaceResult) -> some View {
        Button {
            selectPlace(result)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.mainText)
                        .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.textPrincipal)
                        .lineLimit(1)

                    if !result.secondaryText.isEmpty {
                        Text(result.secondaryText)
                            .font(.raleway("Regular", size: 13, relativeTo: .footnote))
                            .foregroundStyle(DesignColors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                resultArrowChip
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(result.mainText), \(result.secondaryText)")
    }

    /// Small version of the `BondsCard` arrow chip — dashed
    /// cycle-gradient stroke + `arrow.up.right`. Same visual
    /// vocabulary as the chip on the main bond card and on each
    /// bond row in history, sized down to 32pt so multiple
    /// results can stack without crowding.
    private var resultArrowChip: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            DesignColors.calendarPeriodGlyph,
                            DesignColors.calendarFollicularGlyph,
                            DesignColors.calendarFertileGlyph,
                            DesignColors.calendarLutealGlyph,
                            DesignColors.calendarPeriodGlyph,
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.1, dash: [2.5, 3.5])
                )
            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignColors.text)
        }
        .frame(width: 32, height: 32)
    }

    private var resultsSurface: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
    }

    // MARK: - Search logic
    //
    // 300ms debounce on text change; minimum 2-char query;
    // detached task so the request survives view re-renders. Hits
    // `PlacesClient.liveValue` directly for the autocomplete call;
    // `getDetails` runs on tap to fill in lat/lng/timezone.

    private func handleTextChange(_ newValue: String) {
        searchTask?.cancel()

        if isSelectingPlace { return }

        if selectedPlace != nil && newValue != selectedPlace?.name {
            selectedPlace = nil
        }

        guard !newValue.isEmpty, newValue.count >= 2 else {
            searchResults = []
            isShowingResults = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            let results = await fetchResults(for: newValue)

            guard !Task.isCancelled else { return }
            await MainActor.run {
                searchResults = results
                isShowingResults = !results.isEmpty
            }
        }
    }

    /// Force the keyboard down system-wide. `UIWindow.endEditing(true)`
    /// is the canonical native dismissal — it walks the entire
    /// responder chain rooted at the key window and forces the
    /// current first responder (whichever view it is) to resign.
    /// Unlike `UIResponder.resignFirstResponder` sent via
    /// `UIApplication.sendAction`, this works reliably even when
    /// the focused view is buried inside a ZStack overlay (as
    /// AddBond is here) where the responder chain doesn't line
    /// up neatly with the SwiftUI view hierarchy.
    private func dismissKeyboardSystemWide() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .endEditing(true)
    }

    private func fetchResults(
        for query: String
    ) async -> [PlacesAutocompleteTextField.PlaceResult] {
        let client = PlacesClient.liveValue
        do {
            let results = try await client.autocomplete(query)
            return results.map { r in
                PlacesAutocompleteTextField.PlaceResult(
                    id: r.placeId,
                    mainText: r.mainText ?? r.description,
                    secondaryText: r.secondaryText ?? ""
                )
            }
        } catch {
            print("⚠️ Places autocomplete error: \(error)")
            return []
        }
    }

    private func selectPlace(_ result: PlacesAutocompleteTextField.PlaceResult) {
        isSelectingPlace = true
        searchResults = []
        isShowingResults = false

        // Dismiss the keyboard FIRST, *before* changing the
        // text. Changing `text` triggers `onChange` which can
        // race with focus state and on some devices reasserts
        // first responder. Calling `endEditing(true)` on the key
        // window is the canonical UIKit dismissal — stronger
        // than `resignFirstResponder` because it walks the entire
        // responder chain and forces the current first responder
        // (whatever it is) to relinquish focus. Setting
        // `@FocusState` to false in addition keeps SwiftUI's
        // model in sync with the UIKit dismissal.
        dismissKeyboardSystemWide()
        isFocused = false

        text = result.mainText

        // Fallback uses just the autocomplete row data — placeId
        // + display text. lat/lng/timezone are 0/nil. If the
        // details call succeeds we replace this with the richer
        // result; if it fails (network, backend down, rate-limit)
        // the user can still proceed because `selectedPlace` is
        // non-nil and the parent's `canSave` flips true.
        let fallback = PlacesAutocompleteTextField.SelectedPlace(
            placeId: result.id,
            name: result.mainText,
            formattedAddress: result.secondaryText.isEmpty
                ? result.mainText
                : "\(result.mainText), \(result.secondaryText)",
            latitude: 0,
            longitude: 0,
            timezone: nil
        )

        Task {
            let client = PlacesClient.liveValue
            if let details = try? await client.getDetails(result.id) {
                await MainActor.run {
                    selectedPlace = PlacesAutocompleteTextField.SelectedPlace(
                        placeId: details.placeId,
                        name: details.name,
                        formattedAddress: details.formattedAddress,
                        latitude: details.latitude,
                        longitude: details.longitude,
                        timezone: details.timezone
                    )
                    isSelectingPlace = false
                }
            } else {
                await MainActor.run {
                    selectedPlace = fallback
                    isSelectingPlace = false
                }
            }
        }
    }
}
