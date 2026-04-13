import Foundation

// MARK: - Challenge Template

struct ChallengeTemplate: Codable, Sendable {
    let id: String
    let category: String
    let phases: [String]
    let energyMin: Int
    let energyMax: Int
    let title: String
    let description: String
    let tips: [String]
    let goldHint: String
    let validationPrompt: String
}

// MARK: - Challenge Template Pool

enum ChallengeTemplatePool {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _cached: [ChallengeTemplate]?

    static var templates: [ChallengeTemplate] {
        lock.lock()
        defer { lock.unlock() }

        if let cached = _cached { return cached }
        guard let url = Bundle.main.url(forResource: "challenge_templates", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([ChallengeTemplate].self, from: data)
        else {
            return []
        }
        _cached = decoded
        return decoded
    }
}
