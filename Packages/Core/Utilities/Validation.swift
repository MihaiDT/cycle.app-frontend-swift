import Foundation

// MARK: - Validation

public enum Validation {
    public static func email(_ value: String) -> ValidationResult {
        guard !value.isEmpty else {
            return .invalid("Email is required")
        }
        guard value.isValidEmail else {
            return .invalid("Please enter a valid email address")
        }
        return .valid
    }

    public static func password(_ value: String, minLength: Int = 8) -> ValidationResult {
        guard !value.isEmpty else {
            return .invalid("Password is required")
        }
        guard value.count >= minLength else {
            return .invalid("Password must be at least \(minLength) characters")
        }
        guard value.matches(regex: ".*[A-Z]+.*") else {
            return .invalid("Password must contain at least one uppercase letter")
        }
        guard value.matches(regex: ".*[a-z]+.*") else {
            return .invalid("Password must contain at least one lowercase letter")
        }
        guard value.matches(regex: ".*[0-9]+.*") else {
            return .invalid("Password must contain at least one number")
        }
        return .valid
    }

    public static func required(_ value: String, fieldName: String = "This field") -> ValidationResult {
        guard !value.trimmed.isEmpty else {
            return .invalid("\(fieldName) is required")
        }
        return .valid
    }

    public static func minLength(_ value: String, length: Int, fieldName: String = "This field") -> ValidationResult {
        guard value.count >= length else {
            return .invalid("\(fieldName) must be at least \(length) characters")
        }
        return .valid
    }

    public static func maxLength(_ value: String, length: Int, fieldName: String = "This field") -> ValidationResult {
        guard value.count <= length else {
            return .invalid("\(fieldName) must be at most \(length) characters")
        }
        return .valid
    }

    public static func matching(_ value: String, _ other: String, fieldName: String = "Values") -> ValidationResult {
        guard value == other else {
            return .invalid("\(fieldName) do not match")
        }
        return .valid
    }
}

// MARK: - Validation Result

public enum ValidationResult: Equatable, Sendable {
    case valid
    case invalid(String)

    public var isValid: Bool {
        self == .valid
    }

    public var errorMessage: String? {
        if case let .invalid(message) = self {
            return message
        }
        return nil
    }
}

// MARK: - Combine Validations

extension Array where Element == ValidationResult {
    public var combined: ValidationResult {
        for result in self {
            if case .invalid = result {
                return result
            }
        }
        return .valid
    }

    public var allErrors: [String] {
        compactMap { $0.errorMessage }
    }
}
