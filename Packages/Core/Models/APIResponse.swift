import Foundation

// MARK: - API Response Wrapper

public struct APIResponse<T: Codable & Sendable>: Codable, Sendable {
    public let data: T
    public let meta: Meta?

    public init(data: T, meta: Meta? = nil) {
        self.data = data
        self.meta = meta
    }

    public struct Meta: Codable, Sendable {
        public let page: Int?
        public let perPage: Int?
        public let total: Int?
        public let totalPages: Int?

        public init(page: Int? = nil, perPage: Int? = nil, total: Int? = nil, totalPages: Int? = nil) {
            self.page = page
            self.perPage = perPage
            self.total = total
            self.totalPages = totalPages
        }
    }
}

// MARK: - Paginated Response

public struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    public let items: [T]
    public let page: Int
    public let perPage: Int
    public let total: Int
    public let totalPages: Int

    public init(
        items: [T],
        page: Int,
        perPage: Int,
        total: Int,
        totalPages: Int
    ) {
        self.items = items
        self.page = page
        self.perPage = perPage
        self.total = total
        self.totalPages = totalPages
    }

    public var hasNextPage: Bool {
        page < totalPages
    }

    public var hasPreviousPage: Bool {
        page > 1
    }
}

// MARK: - Empty Response

public struct EmptyResponse: Codable, Sendable {
    public init() {}
}
