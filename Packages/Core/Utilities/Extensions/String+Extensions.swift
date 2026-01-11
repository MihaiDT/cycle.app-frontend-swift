import Foundation

// MARK: - String Extensions

extension String {
    public var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isBlank: Bool {
        trimmed.isEmpty
    }

    public var isNotBlank: Bool {
        !isBlank
    }

    public var isValidEmail: Bool {
        let emailPattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return range(of: emailPattern, options: .regularExpression) != nil
    }

    public func truncated(to length: Int, trailing: String = "…") -> String {
        if count <= length {
            return self
        }
        return String(prefix(length)) + trailing
    }

    public var capitalizingFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }

    public func matches(regex: String) -> Bool {
        range(of: regex, options: .regularExpression) != nil
    }
}

// MARK: - URL Initialization

extension URL {
    public init?(string: String?) {
        guard let string, !string.isEmpty else {
            return nil
        }
        self.init(string: string)
    }
}
