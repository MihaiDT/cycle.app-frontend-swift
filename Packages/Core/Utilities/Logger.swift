import Foundation
import os.log

// MARK: - Logger

public enum Log {
    private static let subsystem = "app.cycle"

    public static let general = Logger(subsystem: subsystem, category: "general")
    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let persistence = Logger(subsystem: subsystem, category: "persistence")
    public static let auth = Logger(subsystem: subsystem, category: "auth")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
}

// MARK: - Convenience Extensions

extension Logger {
    public func traceWithContext(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        self.trace("[\(fileName):\(line)] \(function) - \(message)")
    }

    public func success(_ message: String) {
        self.info("✅ \(message)")
    }

    public func failure(_ message: String) {
        self.error("❌ \(message)")
    }
}
