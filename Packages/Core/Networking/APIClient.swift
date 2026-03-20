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
            let body = String(data: data, encoding: .utf8) ?? "no body"
            print("⚠️ API \(httpResponse.statusCode): \(endpoint.path) → \(body)")
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let str = try container.decode(String.self)
                // Try ISO 8601 with fractional seconds first (Go default)
                let fmtFrac = ISO8601DateFormatter()
                fmtFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = fmtFrac.date(from: str) { return date }
                // Fallback: ISO 8601 without fractional seconds
                let fmtBasic = ISO8601DateFormatter()
                fmtBasic.formatOptions = [.withInternetDateTime]
                if let date = fmtBasic.date(from: str) { return date }
                // Fallback: date-only "2026-03-11"
                let dfDate = DateFormatter()
                dfDate.dateFormat = "yyyy-MM-dd"
                dfDate.locale = Locale(identifier: "en_US_POSIX")
                dfDate.timeZone = TimeZone(identifier: "UTC")!
                if let date = dfDate.date(from: str) { return date }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
            }
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
    public static var resolvedBaseURL: URL {
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"],
            let url = URL(string: envURL)
        {
            return url
        }
        #if DEBUG
            return URL(string: "https://dth-backend-277319586889.us-central1.run.app")!
        #else
            return URL(string: "https://dth-backend-277319586889.us-central1.run.app")!
        #endif
    }

    public static func live(
        baseURL: URL = resolvedBaseURL,
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
