import Foundation

// MARK: - API Error

public enum APIError: Error, Equatable, Sendable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case forbidden
    case notFound
    case serverError
    case unknown

    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.serverError, .serverError),
             (.unknown, .unknown):
            true
        case let (.httpError(lhsCode, lhsData), .httpError(rhsCode, rhsData)):
            lhsCode == rhsCode && lhsData == rhsData
        case (.decodingError, .decodingError),
             (.networkError, .networkError):
            true
        default:
            false
        }
    }
}

// MARK: - LocalizedError

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case .invalidResponse:
            "Invalid response from server"
        case let .httpError(statusCode, _):
            "HTTP error: \(statusCode)"
        case let .decodingError(error):
            "Failed to decode response: \(error.localizedDescription)"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case .unauthorized:
            "Unauthorized. Please log in again."
        case .forbidden:
            "You don't have permission to perform this action."
        case .notFound:
            "The requested resource was not found."
        case .serverError:
            "Server error. Please try again later."
        case .unknown:
            "An unknown error occurred."
        }
    }
}

// MARK: - Factory

extension APIError {
    public static func from(statusCode: Int, data: Data) -> APIError {
        switch statusCode {
        case 401:
            .unauthorized
        case 403:
            .forbidden
        case 404:
            .notFound
        case 500...599:
            .serverError
        default:
            .httpError(statusCode: statusCode, data: data)
        }
    }
}
