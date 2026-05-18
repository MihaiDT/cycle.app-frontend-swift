import ComposableArchitecture
import SwiftUI

// MARK: - Edit Profile View
//
// Inline form pushed from ProfileView. Reuses the DS primitives
// (GlassDateButton + DatePickerSheet, PlacesAutocompleteTextField,
// GlassTextField, GlassButton) rather than the onboarding-shaped
// BirthDataView, which is too coupled to OnboardingLayout to embed.

public struct EditProfileView: View {
    @Bindable var store: StoreOf<EditProfileFeature>

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    public init(store: StoreOf<EditProfileFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppLayout.spacingL) {
                    fieldSection(title: "Your name") {
                        GlassTextField(text: $store.userName, placeholder: "Your name")
                    }

                    fieldSection(title: "Birth date") {
                        GlassDateButton(
                            label: "Birth date",
                            value: Self.dateFormatter.string(from: store.birthDate),
                            action: { store.send(.datePickerShown) }
                        )
                    }

                    fieldSection(title: "Birth time") {
                        GlassDateButton(
                            label: "Birth time",
                            value: Self.timeFormatter.string(from: store.birthTime),
                            action: { store.send(.timePickerShown) }
                        )
                    }

                    fieldSection(title: "Birth place") {
                        PlacesAutocompleteTextField(
                            text: $store.birthPlace,
                            selectedPlace: $store.selectedBirthPlace,
                            placeholder: "Where were you born?",
                            onSearch: searchPlaces,
                            onSelect: selectPlace
                        )
                    }

                    Spacer(minLength: AppLayout.spacingL)

                    GlassButton(
                        store.isSaving ? "Saving…" : "Save",
                        action: { store.send(.saveTapped) }
                    )
                    .disabled(!store.canSave)
                    .opacity(store.canSave ? 1 : 0.5)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, AppLayout.horizontalPadding)
                .padding(.top, AppLayout.spacingM)
                .padding(.bottom, AppLayout.spacingXL)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Edit details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(
            isPresented: Binding(
                get: { store.isDatePickerVisible },
                set: { if !$0 { store.send(.datePickerDismissed) } }
            )
        ) {
            DatePickerSheet(
                selection: $store.birthDate,
                isPresented: Binding(
                    get: { store.isDatePickerVisible },
                    set: { if !$0 { store.send(.datePickerDismissed) } }
                ),
                title: "Select your birth date",
                displayedComponents: .date
            )
        }
        .sheet(
            isPresented: Binding(
                get: { store.isTimePickerVisible },
                set: { if !$0 { store.send(.timePickerDismissed) } }
            )
        ) {
            DatePickerSheet(
                selection: $store.birthTime,
                isPresented: Binding(
                    get: { store.isTimePickerVisible },
                    set: { if !$0 { store.send(.timePickerDismissed) } }
                ),
                title: "Select your birth time",
                displayedComponents: .hourAndMinute
            )
        }
    }

    private func fieldSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppLayout.spacingS) {
            Text(title)
                .font(AppTypography.cardEyebrow)
                .tracking(AppTypography.cardEyebrowTracking)
                .foregroundStyle(DesignColors.textSecondary)
            content()
        }
    }

    // MARK: Places callbacks — mirror AppView.swift:60-87. These live
    // in the View layer because PlacesClient is not (yet) a TCA
    // dependency on this feature; the network call is fire-and-forget
    // from the user's typing, and the resolved place is fed back into
    // state via the @Binding.

    @Sendable
    private func searchPlaces(
        _ query: String
    ) async -> [PlacesAutocompleteTextField.PlaceResult] {
        let client = PlacesClient.liveValue
        do {
            let results = try await client.autocomplete(query)
            return results.map { result in
                PlacesAutocompleteTextField.PlaceResult(
                    id: result.placeId,
                    mainText: result.mainText ?? result.description,
                    secondaryText: result.secondaryText ?? ""
                )
            }
        } catch {
            return []
        }
    }

    @Sendable
    private func selectPlace(
        _ result: PlacesAutocompleteTextField.PlaceResult
    ) async -> PlacesAutocompleteTextField.SelectedPlace? {
        let client = PlacesClient.liveValue
        guard let details = try? await client.getDetails(result.id) else { return nil }
        return PlacesAutocompleteTextField.SelectedPlace(
            placeId: details.placeId,
            name: details.name,
            formattedAddress: details.formattedAddress,
            latitude: details.latitude,
            longitude: details.longitude,
            timezone: details.timezone
        )
    }
}