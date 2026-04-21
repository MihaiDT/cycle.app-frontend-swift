import ComposableArchitecture
import Foundation

// MARK: - Lens Preview Client
//
// Dependency that produces today's Lens previews. `liveValue` returns
// hardcoded mock data keyed by phase while the real Lens backend is
// being built. When the backend lands, swap `liveValue` for a real
// fetch — callers stay identical.

public struct LensPreviewClient: Sendable {
    public var previews: @Sendable (CyclePhase, Int) async throws -> [LensPreview]

    public init(
        previews: @escaping @Sendable (CyclePhase, Int) async throws -> [LensPreview]
    ) {
        self.previews = previews
    }
}

// MARK: - Dependency wiring

extension LensPreviewClient: DependencyKey {
    public static let liveValue = LensPreviewClient.mock()
    public static let testValue = LensPreviewClient.mock()
    public static let previewValue = LensPreviewClient.mock()
}

public extension DependencyValues {
    var lensPreview: LensPreviewClient {
        get { self[LensPreviewClient.self] }
        set { self[LensPreviewClient.self] = newValue }
    }
}

// MARK: - Mock implementation

public extension LensPreviewClient {
    /// Hand-crafted previews per phase. We return 3 previews each so the
    /// Home "Your day" section has enough variety to feel curated without
    /// overwhelming the user. Each preview is deterministic per phase so
    /// the same card copy shows all day — switching devices doesn't shift
    /// today's content. The real client can replace this with a stable
    /// per-day seed later.
    static func mock() -> LensPreviewClient {
        LensPreviewClient { phase, cycleDay in
            Self.bundled(for: phase, cycleDay: cycleDay)
        }
    }

    static func bundled(for phase: CyclePhase, cycleDay: Int) -> [LensPreview] {
        switch phase {
        case .menstrual:
            return [
                LensPreview(
                    title: "The quiet power of rest",
                    teaser: "Shedding isn't weakness — it's your body clearing space. Let's explore what it's asking you to release.",
                    durationMinutes: 5,
                    tone: .tender,
                    phase: phase,
                    cycleDay: cycleDay
                ),
                LensPreview(
                    title: "What does 'enough' look like today?",
                    teaser: "A prompt to redefine productivity when your body wants to slow down.",
                    durationMinutes: 4,
                    tone: .reflective,
                    phase: phase,
                    cycleDay: cycleDay
                ),
                LensPreview(
                    title: "Rituals that meet you here",
                    teaser: "Three tiny practices matched to the first days of your cycle.",
                    durationMinutes: 6,
                    tone: .grounding,
                    phase: phase,
                    cycleDay: cycleDay
                )
            ]

        case .follicular:
            return [
                LensPreview(
                    title: "Why follicular feels like possibility",
                    teaser: "Rising estrogen changes your brain's wiring for creativity and courage. Let's turn that into something you can feel.",
                    durationMinutes: 5,
                    tone: .curious,
                    phase: phase,
                    cycleDay: cycleDay
                ),
                LensPreview(
                    title: "Starting small, starting now",
                    teaser: "The one thing you've been circling — this is the week for it.",
                    durationMinutes: 4,
                    tone: .grounding,
                    phase: phase,
                    cycleDay: cycleDay
                ),
                LensPreview(
                    title: "A letter to your luteal self",
                    teaser: "Write something today that you'll thank yourself for in two weeks.",
                    durationMinutes: 7,
                    tone: .reflective,
                    phase: phase,
                    cycleDay: cycleDay
                )
            ]

        case .ovulatory:
            return [
                LensPreview(
                    title: "The magnetism of ovulation",
                    teaser: "You're in the week the world notices. Let's talk about what you want to do with it.",
                    durationMinutes: 5,
                    tone: .curious,
                    phase: phase,
                    cycleDay: cycleDay
                ),
                LensPreview(
                    title: "Conversations you've been avoiding",
                    teaser: "Confidence runs high now. What would be easier to say today?",
                    durationMinutes: 6,
                    tone: .grounding,
                    phase: phase,
                    cycleDay: cycleDay
                ),
                LensPreview(
                    title: "Celebrate without crashing",
                    teaser: "How to ride the peak without burning through your luteal reserves.",
                    durationMinutes: 4,
                    tone: .tender,
                    phase: phase,
                    cycleDay: cycleDay
                )
            ]

        case .luteal:
            return [
                LensPreview(
                    title: "Why softness is strength",
                    teaser: "Luteal rest isn't weakness. Let's unpack what your body is actually asking for.",
                    durationMinutes: 5,
                    tone: .tender,
                    phase: phase,
                    cycleDay: cycleDay
                ),
                LensPreview(
                    title: "The inner critic's favorite week",
                    teaser: "Progesterone amplifies the voice. Learn to hear it without obeying it.",
                    durationMinutes: 6,
                    tone: .reflective,
                    phase: phase,
                    cycleDay: cycleDay
                ),
                LensPreview(
                    title: "Winding down with intention",
                    teaser: "Three closing practices that turn the late-luteal drag into something graceful.",
                    durationMinutes: 5,
                    tone: .grounding,
                    phase: phase,
                    cycleDay: cycleDay
                )
            ]

        case .late:
            return [
                LensPreview(
                    title: "When your cycle is late",
                    teaser: "Late doesn't always mean worry. Let's talk through what your body might be saying.",
                    durationMinutes: 5,
                    tone: .tender,
                    phase: phase,
                    cycleDay: cycleDay
                ),
                LensPreview(
                    title: "Staying grounded in uncertainty",
                    teaser: "A short practice for the days your timing feels off.",
                    durationMinutes: 4,
                    tone: .grounding,
                    phase: phase,
                    cycleDay: cycleDay
                )
            ]
        }
    }
}
