import ComposableArchitecture
import Foundation

// MARK: - Places Client

/// Client for Google Places API operations (proxied through backend)
public struct PlacesClient: Sendable {
    public var autocomplete: @Sendable (String) async throws -> [PlaceAutocompleteResult]
    public var getDetails: @Sendable (String) async throws -> PlaceDetails

    public init(
        autocomplete: @escaping @Sendable (String) async throws -> [PlaceAutocompleteResult],
        getDetails: @escaping @Sendable (String) async throws -> PlaceDetails
    ) {
        self.autocomplete = autocomplete
        self.getDetails = getDetails
    }
}

// MARK: - Models

public struct PlaceAutocompleteResult: Decodable, Sendable, Identifiable, Equatable {
    public let placeId: String
    public let description: String
    public let mainText: String?
    public let secondaryText: String?

    public var id: String { placeId }
}

public struct PlaceDetails: Decodable, Sendable, Equatable {
    public let placeId: String
    public let name: String
    public let formattedAddress: String
    public let latitude: Double
    public let longitude: Double
    public let timezone: String?
}

struct AutocompleteResponse: Decodable {
    let results: [PlaceAutocompleteResult]
}

// MARK: - Dependency Key

extension PlacesClient: DependencyKey {
    public static let liveValue = PlacesClient.live()
    public static let testValue = PlacesClient.mock()
    public static let previewValue = PlacesClient.mock()
}

extension DependencyValues {
    public var placesClient: PlacesClient {
        get { self[PlacesClient.self] }
        set { self[PlacesClient.self] = newValue }
    }
}

// MARK: - Live Implementation

extension PlacesClient {
    public static func live() -> Self {
        @Dependency(\.apiClient) var apiClient

        return PlacesClient(
            autocomplete: { input in
                let endpoint = Endpoint.get(
                    "/api/places/autocomplete",
                    queryItems: [URLQueryItem(name: "input", value: input)]
                )
                let response: AutocompleteResponse = try await apiClient.send(endpoint)
                return response.results
            },
            getDetails: { placeId in
                let endpoint = Endpoint.get(
                    "/api/places/details",
                    queryItems: [URLQueryItem(name: "place_id", value: placeId)]
                )
                return try await apiClient.send(endpoint)
            }
        )
    }
}

// MARK: - Mock Implementation

extension PlacesClient {
    public static func mock() -> Self {
        PlacesClient(
            autocomplete: { _ in
                [
                    PlaceAutocompleteResult(
                        placeId: "mock_1",
                        description: "Bucharest, Romania",
                        mainText: "Bucharest",
                        secondaryText: "Romania"
                    ),
                    PlaceAutocompleteResult(
                        placeId: "mock_2",
                        description: "Budapest, Hungary",
                        mainText: "Budapest",
                        secondaryText: "Hungary"
                    ),
                ]
            },
            getDetails: { placeId in
                PlaceDetails(
                    placeId: placeId,
                    name: "Bucharest",
                    formattedAddress: "Bucharest, Romania",
                    latitude: 44.4268,
                    longitude: 26.1025,
                    timezone: "Europe/Bucharest"
                )
            }
        )
    }
}
