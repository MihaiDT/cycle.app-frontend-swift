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

    public static func post(_ path: String, body: some Encodable & Sendable) -> Endpoint {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let data = try? encoder.encode(body)
        return Endpoint(path: path, method: .post, body: data)
    }

    public static func put(_ path: String, body: some Encodable & Sendable) -> Endpoint {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let data = try? encoder.encode(body)
        return Endpoint(path: path, method: .put, body: data)
    }

    public static func patch(_ path: String, body: some Encodable & Sendable) -> Endpoint {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let data = try? encoder.encode(body)
        return Endpoint(path: path, method: .patch, body: data)
    }

    public static func delete(_ path: String) -> Endpoint {
        Endpoint(path: path, method: .delete)
    }

    public func authenticated(with token: String) -> Endpoint {
        var newHeaders = headers
        newHeaders["Authorization"] = "Bearer \(token)"
        return Endpoint(
            path: path,
            method: method,
            headers: newHeaders,
            queryItems: queryItems,
            body: body
        )
    }
}
