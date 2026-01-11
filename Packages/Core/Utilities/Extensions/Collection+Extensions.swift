import Foundation

// MARK: - Optional Extensions

extension Optional where Wrapped == String {
    public var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }

    public var orEmpty: String {
        self ?? ""
    }
}

extension Optional {
    public func orThrow(_ error: Error) throws -> Wrapped {
        guard let value = self else {
            throw error
        }
        return value
    }
}

// MARK: - Array Extensions

extension Array {
    public subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Array where Element: Identifiable {
    public mutating func update(_ element: Element) {
        guard let index = firstIndex(where: { $0.id == element.id }) else {
            return
        }
        self[index] = element
    }

    public mutating func upsert(_ element: Element) {
        if let index = firstIndex(where: { $0.id == element.id }) {
            self[index] = element
        } else {
            append(element)
        }
    }
}

// MARK: - Collection Extensions

extension Collection {
    public var isNotEmpty: Bool {
        !isEmpty
    }
}

// MARK: - Dictionary Extensions

extension Dictionary {
    public mutating func merge(_ other: [Key: Value]) {
        for (key, value) in other {
            self[key] = value
        }
    }
}
