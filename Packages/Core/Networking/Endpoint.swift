import Foundation

// MARK: - Endpoint

public struct Endpoint: Sendable {
    public let path: String
    public let method: HTTPMethod
    public let headers: [String: String]
    public let queryItems: [URLQueryItem]
    public let body: Data?

    public init(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
    }

    public func urlRequest(baseURL: URL) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body

        // Default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }
}

// MARK: - HTTP Method

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Endpoint Builder

extension Endpoint {
    public static func get(_ path: String, queryItems: [URLQueryItem] = []) -> Endpoint {
        Endpoint(path: path, method: .get, queryItems: queryItems)
    }

    /// Date encoding: extracts local calendar components and encodes as UTC midnight ISO 8601.
    /// This prevents timezone-induced date shifts (e.g., local Feb 22 00:00 EET → "2025-02-21T22:00:00Z").
    private static let dateEncoder: JSONEncoder.DateEncodingStrategy = .custom { date, encoder in
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let utcDate = utcCal.date(from: comps) ?? date
        var container = encoder.singleValueContainer()
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        try container.encode(fmt.string(from: utcDate))
    }

    public static func post(_ path: String, body: some Encodable & Sendable) -> Endpoint {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = dateEncoder
        let data = try? encoder.encode(body)
        return Endpoint(path: path, method: .post, body: data)
    }

    public static func put(_ path: String, body: some Encodable & Sendable) -> Endpoint {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = dateEncoder
        let data = try? encoder.encode(body)
        return Endpoint(path: path, method: .put, body: data)
    }

    public static func patch(_ path: String, body: some Encodable & Sendable) -> Endpoint {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = dateEncoder
        let data = try? encoder.encode(body)
        return Endpoint(path: path, method: .patch, body: data)
    }

    public static func delete(_ path: String) -> Endpoint {
        Endpoint(path: path, method: .delete)
    }
}
