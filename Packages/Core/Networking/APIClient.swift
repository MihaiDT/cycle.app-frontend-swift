import ComposableArchitecture
import Foundation

// MARK: - API Client

public struct APIClient: Sendable {
    public var request: @Sendable (Endpoint) async throws -> (Data, URLResponse)
    public var upload: @Sendable (Endpoint, Data) async throws -> (Data, URLResponse)
    public var download: @Sendable (Endpoint) async throws -> URL

    public init(
        request: @escaping @Sendable (Endpoint) async throws -> (Data, URLResponse),
        upload: @escaping @Sendable (Endpoint, Data) async throws -> (Data, URLResponse),
        download: @escaping @Sendable (Endpoint) async throws -> URL
    ) {
        self.request = request
        self.upload = upload
        self.download = download
    }
}

// MARK: - Convenience Methods

extension APIClient {
    public func send<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T {
        let (data, response) = try await request(endpoint)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    public func send(_ endpoint: Endpoint) async throws {
        let (data, response) = try await request(endpoint)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
    }
}

// MARK: - Dependency

extension APIClient: DependencyKey {
    public static let liveValue = APIClient.live()
    public static let testValue = APIClient.mock()
    public static let previewValue = APIClient.mock()
}

extension DependencyValues {
    public var apiClient: APIClient {
        get { self[APIClient.self] }
        set { self[APIClient.self] = newValue }
    }
}

// MARK: - Live Implementation

extension APIClient {
    public static func live(
        baseURL: URL = URL(string: "https://api.cycle.app")!,
        session: URLSession = .shared
    ) -> Self {
        APIClient(
            request: { endpoint in
                let request = try endpoint.urlRequest(baseURL: baseURL)
                return try await session.data(for: request)
            },
            upload: { endpoint, data in
                var request = try endpoint.urlRequest(baseURL: baseURL)
                request.httpBody = data
                return try await session.data(for: request)
            },
            download: { endpoint in
                let request = try endpoint.urlRequest(baseURL: baseURL)
                let (url, _) = try await session.download(for: request)
                return url
            }
        )
    }
}

// MARK: - Mock Implementation

extension APIClient {
    public static func mock() -> Self {
        APIClient(
            request: { _ in
                (Data(), HTTPURLResponse())
            },
            upload: { _, _ in
                (Data(), HTTPURLResponse())
            },
            download: { _ in
                URL(fileURLWithPath: "/tmp/mock")
            }
        )
    }
}
