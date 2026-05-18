import ComposableArchitecture
import Foundation

// MARK: - Me Feature
//
// Editorial home for the user's personal narrative — three sections:
// Povestea ta (chapter card), Insightul zilei (Stoic insight),
// Legaturile tale (relationships empty-state). Data is mock for now;
// real wiring to SwiftData lands in a future cycle.

@Reducer
public struct MeFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var story: MyStoryCard
        public var insight: DailyInsightItem
        public var insightPageIndex: Int
        public var bonds: IdentifiedArrayOf<Bond>
        /// Every insight the user has hearted. Owned here so it
        /// survives the InsightHistory overlay being dismissed.
        public var savedInsights: IdentifiedArrayOf<DailyInsightItem>
        /// Tracks whether the *currently displayed* insight is in
        /// `savedInsights` — drives the heart fill on the Me-tab
        /// card without having to re-scan the collection on each
        /// render.
        public var isInsightSaved: Bool

        @Presents public var addBond: AddBondFeature.State?
        @Presents public var bondReading: BondReadingFeature.State?
        @Presents public var bondHistory: BondHistoryFeature.State?
        @Presents public var insightHistory: InsightHistoryFeature.State?
        @Presents public var meReading: MeReadingFeature.State?
        @Presents public var profile: ProfileFeature.State?

        public init(
            story: MyStoryCard = .mock,
            insight: DailyInsightItem = .mock,
            insightPageIndex: Int = 0,
            bonds: IdentifiedArrayOf<Bond> = [],
            savedInsights: IdentifiedArrayOf<DailyInsightItem> = IdentifiedArrayOf(
                uniqueElements: DailyInsightItem.mockSaved
            )
        ) {
            self.story = story
            self.insight = insight
            self.insightPageIndex = insightPageIndex
            self.bonds = bonds
            self.savedInsights = savedInsights
            self.isInsightSaved = savedInsights[id: insight.id] != nil
        }
    }

    public enum Action: Sendable {
        case avatarTapped
        case settingsTapped
        case storyTapped
        case insightSavedTapped
        case insightArrowTapped
        case insightPaginationTapped(Int)
        case bondsAddTapped
        case bondsArrowTapped
        case bondTapped(Bond.ID)
        case dismissAddBond
        case dismissBondHistoryAfterPush
        case dismissProfile
        case addBond(PresentationAction<AddBondFeature.Action>)
        case bondReading(PresentationAction<BondReadingFeature.Action>)
        case bondHistory(PresentationAction<BondHistoryFeature.Action>)
        case insightHistory(PresentationAction<InsightHistoryFeature.Action>)
        case meReading(PresentationAction<MeReadingFeature.Action>)
        case profile(PresentationAction<ProfileFeature.Action>)
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case showAvatar
            case showCycleEditor
            case cycleDataChanged
            case showSettings
            case showStory
            case didLogout
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .avatarTapped:
                state.profile = ProfileFeature.State()
                return .send(.delegate(.showAvatar))
            case .settingsTapped:
                return .send(.delegate(.showSettings))
            case .storyTapped:
                // StoryHeroCard tap → present the personal reading
                // overlay. Mirrors the bondTapped flow: seed the
                // child state and let HomeView pick it up via
                // `\.meState.meReading`. The delegate is left in
                // place so callers that already listen for it
                // continue to receive a side-channel notification,
                // but the canonical surface is now this overlay.
                state.meReading = MeReadingFeature.State()
                return .send(.delegate(.showStory))
            case .insightSavedTapped:
                // Heart on the main Daily Insight card: toggle the
                // saved flag and mirror the change into the
                // canonical `savedInsights` collection so it shows
                // up (or disappears) in the InsightHistory grid.
                //
                // Insight + id are copied to locals before mutating
                // any collection on `state` — otherwise Swift's
                // exclusivity rules trip on `state.savedInsights
                // .insert(state.insight, at: 0)` (read + inout
                // write to `state` in one expression).
                let currentInsight = state.insight
                let currentInsightID = state.insight.id
                state.isInsightSaved.toggle()
                if state.isInsightSaved {
                    state.savedInsights.insert(currentInsight, at: 0)
                    // Mirror into the open history overlay too so
                    // the user sees the new card the moment they
                    // tap through after liking.
                    state.insightHistory?.insights.insert(currentInsight, at: 0)
                } else {
                    state.savedInsights.remove(id: currentInsightID)
                    state.insightHistory?.insights.remove(id: currentInsightID)
                }
                return .none
            case .insightArrowTapped:
                // Arrow chip / card tap on the Daily Insight card
                // → open the saved-insights pinterest grid. Same
                // overlay pattern as BondHistory: snapshot the
                // current collection into the child state.
                state.insightHistory = InsightHistoryFeature.State(
                    insights: state.savedInsights
                )
                return .none
            case .insightPaginationTapped(let index):
                state.insightPageIndex = index
                return .none
            case .bondsAddTapped:
                state.addBond = AddBondFeature.State()
                return .none
            case .bondsArrowTapped:
                // Card arrow → open the history list, snapshotting
                // the current bonds collection into the child.
                state.bondHistory = BondHistoryFeature.State(bonds: state.bonds)
                return .none
            case .bondTapped(let id):
                // Bond list / card tap → open reading screen with a
                // fresh `BondReadingFeature.State`. Mock themes are
                // attached on the bond model itself, so no extra
                // hydration is needed here.
                guard let bond = state.bonds[id: id] else { return .none }
                state.bondReading = BondReadingFeature.State(bond: bond)
                return .none
            case .dismissAddBond:
                state.addBond = nil
                return .none
            case .addBond(.presented(.delegate(.didSave(let bond)))):
                // Just append — the child calls `dismiss()` after
                // sending this delegate, which kicks the `.ifLet`
                // and clears state.addBond automatically. Setting it
                // here too races with dismiss() and freezes the UI.
                // The bond is also attached to a fresh mock theme
                // set so the reading screen has something to show
                // until the real engine is wired in.
                var hydrated = bond
                if hydrated.themes.isEmpty {
                    hydrated.themes = BondTheme.mockSet(seed: state.bonds.count)
                }
                state.bonds.append(hydrated)
                // Mirror into the history overlay if it happens to
                // be alive (user came in via the BondsCard arrow →
                // history → Add). Without this the history list
                // would still show the pre-save snapshot when the
                // user backs out of the reading.
                state.bondHistory?.bonds.append(hydrated)
                // Auto-open the reading right after save so the
                // user lands straight on the interpretation. The
                // reading sits at zIndex 8 and slides in over
                // AddBond (zIndex 7) before AddBond dismisses
                // itself 360ms later.
                state.bondReading = BondReadingFeature.State(bond: hydrated)
                return .none
            case .addBond:
                return .none
            case .bondReading:
                return .none
            case .bondHistory(.presented(.delegate(.openReading(let id)))):
                // Row tap from history → present the reading on
                // top (zIndex 8 covers history at zIndex 6). We
                // intentionally *keep* `state.bondHistory` alive
                // underneath so that when the user taps X on the
                // reading screen, history reappears — that gives
                // them back-stack-style "return to the previous
                // screen" behaviour without an explicit nav stack.
                guard let bond = state.bonds[id: id] else { return .none }
                state.bondReading = BondReadingFeature.State(bond: bond)
                return .none
            case .bondHistory(.presented(.delegate(.openAddBond))):
                // Same back-stack pattern: AddBond mounts on top
                // (zIndex 7) but history stays alive at zIndex 6,
                // so completing or backing out of AddBond returns
                // the user to history rather than to the Me view.
                state.addBond = AddBondFeature.State()
                return .none
            case .dismissBondHistoryAfterPush:
                // Kept as a no-op so legacy callers compile; the
                // back-stack pattern above replaced the delayed
                // dismiss flow.
                return .none
            case .bondHistory:
                return .none
            case .insightHistory(.presented(.delegate(.unliked(let id)))):
                // Child removed an insight from its snapshot —
                // mirror the deletion into the canonical
                // `savedInsights` so it stays unliked after the
                // overlay is dismissed. Also flip the heart on the
                // main card if the unliked id matches the
                // currently displayed insight.
                state.savedInsights.remove(id: id)
                if state.insight.id == id {
                    state.isInsightSaved = false
                }
                return .none
            case .insightHistory:
                return .none
            case .meReading:
                return .none
            case .profile(.presented(.delegate(.didLogout))):
                state.profile = nil
                return .send(.delegate(.didLogout))
            case .profile(.presented(.delegate(.showCycleEditor))):
                // Bubble up — HomeFeature handles the actual editor push.
                return .send(.delegate(.showCycleEditor))
            case .profile(.presented(.delegate(.cycleDataChanged))):
                return .send(.delegate(.cycleDataChanged))
            case .profile:
                return .none
            case .dismissProfile:
                state.profile = nil
                return .none
            case .delegate:
                return .none
            }
        }
        .ifLet(\.$addBond, action: \.addBond) {
            AddBondFeature()
        }
        .ifLet(\.$bondReading, action: \.bondReading) {
            BondReadingFeature()
        }
        .ifLet(\.$bondHistory, action: \.bondHistory) {
            BondHistoryFeature()
        }
        .ifLet(\.$insightHistory, action: \.insightHistory) {
            InsightHistoryFeature()
        }
        .ifLet(\.$meReading, action: \.meReading) {
            MeReadingFeature()
        }
        .ifLet(\.$profile, action: \.profile) {
            ProfileFeature()
        }
    }
}
