import Foundation

// MARK: - Cycle Live Content
//
// Editorial snippet for the Journey "Cycle Live" widget. Each snippet is
// derived from the active phase plus (optionally) the category of the
// Your moment tile on Rhythm. When a category is present, the copy frames
// *why* that category fits this phase, so Journey reads as the context
// behind the action the user is taking on Rhythm — never a contradiction.

public struct CycleLiveContent: Equatable, Sendable {
    public let phase: CyclePhase
    public let cycleDay: Int?
    public let category: String?
    public let title: String
    public let body: String

    public init(
        phase: CyclePhase,
        cycleDay: Int?,
        category: String?,
        title: String,
        body: String
    ) {
        self.phase = phase
        self.cycleDay = cycleDay
        self.category = category
        self.title = title
        self.body = body
    }
}
