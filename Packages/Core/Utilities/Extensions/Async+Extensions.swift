import Foundation

// MARK: - Result Extensions

extension Result {
    public var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    public var isFailure: Bool {
        !isSuccess
    }

    public var value: Success? {
        try? get()
    }

    public var error: Failure? {
        if case let .failure(error) = self {
            return error
        }
        return nil
    }
}

// MARK: - Task Extensions

extension Task where Success == Never, Failure == Never {
    public static func sleep(seconds: Double) async throws {
        try await sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
