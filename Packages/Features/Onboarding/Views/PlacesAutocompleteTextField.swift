import SwiftUI

// MARK: - Places Autocomplete Text Field

/// A text field with places autocomplete dropdown
public struct PlacesAutocompleteTextField: View {
    @Binding public var text: String
    @Binding public var selectedPlace: SelectedPlace?
    public let placeholder: String

    @State private var isShowingResults = false
    @State private var searchResults: [PlaceResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var isSelectingPlace = false

    // Simulated results for UI preview (real API will be used via PlacesClient)
    private let onSearch: (@Sendable (String) async -> [PlaceResult])?
    private let onSelect: (@Sendable (PlaceResult) async -> SelectedPlace?)?

    public struct SelectedPlace: Equatable, Sendable {
        public let placeId: String
        public let name: String
        public let formattedAddress: String
        public let latitude: Double
        public let longitude: Double
        public let timezone: String?

        public init(
            placeId: String,
            name: String,
            formattedAddress: String,
            latitude: Double,
            longitude: Double,
            timezone: String? = nil
        ) {
            self.placeId = placeId
            self.name = name
            self.formattedAddress = formattedAddress
            self.latitude = latitude
            self.longitude = longitude
            self.timezone = timezone
        }
    }

    public struct PlaceResult: Identifiable, Equatable, Sendable {
        public let id: String
        public let mainText: String
        public let secondaryText: String

        public init(id: String, mainText: String, secondaryText: String) {
            self.id = id
            self.mainText = mainText
            self.secondaryText = secondaryText
        }
    }

    public init(
        text: Binding<String>,
        selectedPlace: Binding<SelectedPlace?>,
        placeholder: String = "Search location",
        onSearch: (@Sendable (String) async -> [PlaceResult])? = nil,
        onSelect: (@Sendable (PlaceResult) async -> SelectedPlace?)? = nil
    ) {
        self._text = text
        self._selectedPlace = selectedPlace
        self.placeholder = placeholder
        self.onSearch = onSearch
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Text field
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(DesignColors.accentWarm)
                    .accessibilityHidden(true)

                TextField(
                    "",
                    text: $text,
                    prompt: Text(placeholder)
                        .font(.raleway("Regular", size: 16, relativeTo: .body))
                        .foregroundColor(DesignColors.text.opacity(0.5))
                )
                .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                .foregroundColor(DesignColors.text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .onChange(of: text) { oldValue, newValue in
                    handleTextChange(newValue)
                }
                .onSubmit {
                    isShowingResults = false
                }
                .accessibilityLabel(placeholder)

                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                        .accessibilityLabel("Searching")
                } else if !text.isEmpty {
                    Button(action: {
                        text = ""
                        selectedPlace = nil
                        searchResults = []
                        isShowingResults = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(DesignColors.text.opacity(0.4))
                    }
                    .accessibilityLabel("Clear text")
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
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
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)

            // Results dropdown
            if isShowingResults && !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(searchResults) { result in
                        Button(action: {
                            selectPlace(result)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 14))
                                    .foregroundColor(DesignColors.accentWarm.opacity(0.8))
                                    .frame(width: 24)
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.mainText)
                                        .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                                        .foregroundColor(DesignColors.text)
                                        .lineLimit(1)

                                    if !result.secondaryText.isEmpty {
                                        Text(result.secondaryText)
                                            .font(.raleway("Regular", size: 12, relativeTo: .caption))
                                            .foregroundColor(DesignColors.textSecondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(result.mainText), \(result.secondaryText)")
                        .accessibilityAddTraits(.isButton)

                        if result.id != searchResults.last?.id {
                            Divider()
                                .background(DesignColors.text.opacity(0.1))
                                .padding(.horizontal, 16)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .padding(.top, 8)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isShowingResults)
    }

    private func handleTextChange(_ newValue: String) {
        // Cancel previous search
        searchTask?.cancel()

        // Don't search when programmatically setting text after selection
        if isSelectingPlace { return }

        // Clear selection if user types
        if selectedPlace != nil && newValue != selectedPlace?.name {
            selectedPlace = nil
        }

        guard !newValue.isEmpty, newValue.count >= 2 else {
            searchResults = []
            isShowingResults = false
            return
        }

        // Debounce search
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms

            guard !Task.isCancelled else { return }

            await MainActor.run {
                isSearching = true
            }

            // Perform search in a detached context so cancellation doesn't kill the HTTP request
            let searchClosure = onSearch
            let searchValue = newValue
            let results: [PlaceResult]
            if let searchClosure {
                results = await Task.detached { @Sendable in
                    await searchClosure(searchValue)
                }.value
            } else {
                results = mockSearch(newValue)
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                searchResults = results
                isShowingResults = !results.isEmpty
                isSearching = false
            }
        }
    }

    private func selectPlace(_ result: PlaceResult) {
        isSelectingPlace = true
        searchResults = []
        isShowingResults = false
        text = result.mainText

        Task {
            // Get full details
            if let details = await onSelect?(result) {
                await MainActor.run {
                    selectedPlace = details
                    isSelectingPlace = false
                }
            } else {
                // Mock selection
                await MainActor.run {
                    selectedPlace = SelectedPlace(
                        placeId: result.id,
                        name: result.mainText,
                        formattedAddress: "\(result.mainText), \(result.secondaryText)",
                        latitude: 0,
                        longitude: 0
                    )
                    isSelectingPlace = false
                }
            }
        }
    }

    // Mock search for preview
    private func mockSearch(_ query: String) -> [PlaceResult] {
        let mockPlaces = [
            PlaceResult(id: "1", mainText: "Bucharest", secondaryText: "Romania"),
            PlaceResult(id: "2", mainText: "Budapest", secondaryText: "Hungary"),
            PlaceResult(id: "3", mainText: "Berlin", secondaryText: "Germany"),
            PlaceResult(id: "4", mainText: "Barcelona", secondaryText: "Spain"),
            PlaceResult(id: "5", mainText: "Brussels", secondaryText: "Belgium"),
        ]
        return mockPlaces.filter {
            $0.mainText.lowercased().contains(query.lowercased())
                || $0.secondaryText.lowercased().contains(query.lowercased())
        }
    }
}

// MARK: - Preview

#Preview("Places Autocomplete") {
    ZStack {
        LinearGradient(
            colors: [.white, DesignColors.onboardingPreviewTint],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 24) {
            PlacesAutocompleteTextField(
                text: .constant(""),
                selectedPlace: .constant(nil),
                placeholder: "Where were you born?"
            )

            PlacesAutocompleteTextField(
                text: .constant("Buc"),
                selectedPlace: .constant(nil),
                placeholder: "Where were you born?"
            )
        }
        .padding(.horizontal, 32)
    }
}
