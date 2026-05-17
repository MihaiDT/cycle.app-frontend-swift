import ComposableArchitecture
import Foundation

// MARK: - Me Reading Feature
//
// User's personal reading flow — analogous to BondReadingFeature but
// the subject is the user herself (the chapters live under MyStory).
// `currentIndex` points into `chapters`; the view animates between
// them. `nextTapped` past the last chapter dismisses the flow;
// `previousTapped` from the first chapter also dismisses, mirroring
// BondReading so back/close behave consistently. Chapter labels can
// also be tapped directly in the top carousel.

@Reducer
public struct MeReadingFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var chapters: [MeChapter]
        public var currentIndex: Int = 0
        public var lastNavigation: NavigationDirection = .forward

        public init(chapters: [MeChapter] = MeChapter.mockSet, currentIndex: Int = 0) {
            self.chapters = chapters
            self.currentIndex = currentIndex
        }

        public enum NavigationDirection: Equatable, Sendable {
            case forward
            case backward
        }

        public var isAtFirst: Bool { currentIndex <= 0 }
        public var isAtLast: Bool { currentIndex >= chapters.count - 1 }

        public var currentChapter: MeChapter? {
            guard chapters.indices.contains(currentIndex) else { return nil }
            return chapters[currentIndex]
        }
    }

    public enum Action: Sendable {
        case nextTapped
        case previousTapped
        case closeTapped
        case chapterSelected(Int)
    }

    public init() {}

    @Dependency(\.dismiss) var dismiss

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .nextTapped:
                if state.isAtLast {
                    return .run { _ in await dismiss() }
                }
                state.lastNavigation = .forward
                state.currentIndex += 1
                return .none

            case .previousTapped:
                if state.isAtFirst {
                    return .run { _ in await dismiss() }
                }
                state.lastNavigation = .backward
                state.currentIndex -= 1
                return .none

            case .closeTapped:
                return .run { _ in await dismiss() }

            case .chapterSelected(let index):
                guard state.chapters.indices.contains(index),
                      index != state.currentIndex
                else { return .none }
                state.lastNavigation = index > state.currentIndex ? .forward : .backward
                state.currentIndex = index
                return .none
            }
        }
    }
}

// MARK: - Chapter Model

public struct MeChapter: Equatable, Sendable, Identifiable, Hashable {
    public let id: UUID
    /// Short label rendered in the top carousel strip.
    public let label: String
    /// Pill subtitle above the title — same role as BondTheme.subtitle.
    public let eyebrow: String
    /// Editorial title in the body.
    public let title: String
    /// Long reading copy.
    public let body: String

    public init(
        id: UUID = UUID(),
        label: String,
        eyebrow: String,
        title: String,
        body: String
    ) {
        self.id = id
        self.label = label
        self.eyebrow = eyebrow
        self.title = title
        self.body = body
    }
}

extension MeChapter {
    public static let mockSet: [MeChapter] = [
        MeChapter(
            label: "Body Whispers",
            eyebrow: "Body",
            title: "What your body keeps trying to say",
            body: """
            Your body has been talking in the same low voice for months — \
            the tightness behind your shoulder blades when a week starts unresolved, \
            the way your jaw softens on the days you eat slowly, the small hum in your \
            chest when you stop apologising for needing rest. \
            None of these are symptoms. They are sentences. \
            The work this season is not louder rituals — it is staying near long enough \
            to hear the whole paragraph instead of catching every third word.
            """
        ),
        MeChapter(
            label: "Cycle Wisdom",
            eyebrow: "Rhythm",
            title: "The shape of your month",
            body: """
            Your follicular week wants horizons, not lists — the planning you do there \
            holds longer than the planning you force in your luteal week. \
            Ovulation is your clearest voice; it is also when you are most likely to \
            over-promise, because everything feels possible at once. \
            Your luteal phase is not a smaller version of you — it is a different \
            instrument, tuned for editing, refining, ending things kindly. \
            Bleeding is the doorway, not the punishment for what you did all month.
            """
        ),
        MeChapter(
            label: "Emotional Patterns",
            eyebrow: "Inner weather",
            title: "How you metabolise feeling",
            body: """
            You feel first, then narrate — which means the story you tell yourself about \
            an emotion is always one step behind the emotion itself. \
            When you slow down enough to feel without explaining, the explanation that \
            arrives later is gentler than the one you would have rushed to write. \
            Your default move under pressure is to make yourself smaller and more useful; \
            the work is noticing the moment that decision happens and choosing differently \
            twice a week, on purpose. \
            Small refusals teach your body that staying whole is safe.
            """
        ),
        MeChapter(
            label: "Hidden Strength",
            eyebrow: "Becoming",
            title: "The strength no one names",
            body: """
            Your steadiness is mistaken for ease — it is not ease, it is practice. \
            You return to people without scorekeeping, you keep promises that nobody \
            witnessed, you let yourself be moved without performing the movement. \
            These are not soft skills; they are the load-bearing kind. \
            What you are learning this chapter is to let the same patience you offer \
            others land back on yourself — to be your own slow friend, not your own \
            sharpest critic. \
            The strength is already there. The next step is letting yourself feel it.
            """
        ),
    ]
}
