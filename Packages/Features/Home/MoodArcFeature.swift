import ComposableArchitecture
import Inject
import SwiftUI
import UIKit

// MARK: - Mood Arc Feature

@Reducer
public struct MoodArcFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var selectedIndex: Int = 2
        public var isDragging: Bool = false
        public var isSubmitting: Bool = false
        public var error: String?

        public init() {}

        public var selectedMood: Mood { Mood.allCases[selectedIndex] }
    }

    public enum Action: Sendable {
        case moodChanged(Int)
        case dragStarted
        case dragEnded
        case continueTapped
        case submitResponse(Result<DailyReportResponse, Error>)
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case didLogMood(Int)
        }
    }

    @Dependency(\.hbiLocal) var hbiLocal
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .moodChanged(index):
                let clamped = min(max(index, 0), Mood.allCases.count - 1)
                if clamped != state.selectedIndex {
                    state.selectedIndex = clamped
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                return .none

            case .dragStarted:
                state.isDragging = true
                return .none

            case .dragEnded:
                state.isDragging = false
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                return .none

            case .continueTapped:
                state.isSubmitting = true
                state.error = nil
                let moodValue = state.selectedIndex + 1 // 1-5
                let request = DailyReportRequest(
                    energyLevel: 3,
                    stressLevel: 3,
                    sleepQuality: 3,
                    moodLevel: moodValue
                )
                return .run { send in
                    let result = await Result {
                        try await hbiLocal.submitDailyReport(request)
                    }
                    await send(.submitResponse(result))
                }

            case .submitResponse(.success):
                state.isSubmitting = false
                let value = state.selectedIndex + 1
                return .run { send in
                    await send(.delegate(.didLogMood(value)))
                    await dismiss()
                }

            case .submitResponse(.failure(let error)):
                state.isSubmitting = false
                state.error = error.localizedDescription
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Mood Model

public enum Mood: String, CaseIterable, Sendable {
    case awful, bad, okay, good, great

    public var emoji: String {
        switch self {
        case .awful: "😔"
        case .bad: "😕"
        case .okay: "😐"
        case .good: "🙂"
        case .great: "😊"
        }
    }

    public var label: String {
        switch self {
        case .awful: "Awful"
        case .bad: "Bad"
        case .okay: "Okay"
        case .good: "Good"
        case .great: "Great"
        }
    }
}

// MARK: - Mood Arc View

public struct MoodArcView: View {
    @ObserveInjection var inject
    @Bindable var store: StoreOf<MoodArcFeature>

    @State private var showContent = false

    public init(store: StoreOf<MoodArcFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(DesignColors.divider)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 24)

            // Title — left aligned like Figma
            Text("How are you\nfeeling today?")
                .font(.raleway("Bold", size: 30, relativeTo: .title))
                .foregroundStyle(DesignColors.text)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .center)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 12)
                .padding(.horizontal, AppLayout.horizontalPadding)

            // Hint — left aligned
            HStack(spacing: 6) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 13, weight: .medium))
                Text("Drag to adjust")
                    .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
            }
            .foregroundStyle(DesignColors.textPlaceholder)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 20)
            .padding(.horizontal, AppLayout.horizontalPadding)
            .opacity(showContent ? 1 : 0)

            // Arc — takes up all remaining space
            MoodArcDial(
                selectedIndex: store.selectedIndex,
                isDragging: store.isDragging,
                onDragStarted: { store.send(.dragStarted) },
                onDragChanged: { store.send(.moodChanged($0)) },
                onDragEnded: { store.send(.dragEnded) }
            )
            .opacity(showContent ? 1 : 0)

            // Error
            if let error = store.error {
                Text(error)
                    .font(.raleway("Regular", size: 13, relativeTo: .caption))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.bottom, 8)
                    .padding(.horizontal, AppLayout.horizontalPadding)
            }

            // Continue button — dark, full width, like Figma
            Button(action: { store.send(.continueTapped) }) {
                HStack(spacing: 12) {
                    if store.isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(store.isSubmitting ? "Saving..." : "Continue")
                        .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                    if !store.isSubmitting {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppLayout.buttonHeight)
                .background {
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .fill(DesignColors.text)
                }
            }
            .buttonStyle(.plain)
            .disabled(store.isSubmitting)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(DesignColors.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
        }
        .enableInjection()
    }
}

// MARK: - Mood Arc Dial (Bézier curve — direct control over shape)

private struct MoodArcDial: View {
    let selectedIndex: Int
    let isDragging: Bool
    let onDragStarted: () -> Void
    let onDragChanged: (Int) -> Void
    let onDragEnded: () -> Void

    private let moods = Mood.allCases

    // Bézier control points as fractions of view size.
    // P0 = start (bottom-left), Pc = control (pulls curve left), P1 = end (top-right).
    private let p0 = CGPoint(x: 0.10, y: 0.92)
    private let pc = CGPoint(x: 0.52, y: 0.04)
    private let p1 = CGPoint(x: 0.96, y: 0.04)

    // Track extends slightly beyond moods (t < 0 and t > 1)
    private let trackExtend: CGFloat = 0.07

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let sp0 = CGPoint(x: p0.x * w, y: p0.y * h)
            let spc = CGPoint(x: pc.x * w, y: pc.y * h)
            let sp1 = CGPoint(x: p1.x * w, y: p1.y * h)

            ZStack(alignment: .topLeading) {
                // --- Track (dark line, extends beyond moods) ---
                BezierArc(p0: sp0, pc: spc, p1: sp1, tStart: -trackExtend, tEnd: 1 + trackExtend)
                    .stroke(DesignColors.text, style: StrokeStyle(lineWidth: 8, lineCap: .round))

                // --- Active portion (warm accent, from start to selected) ---
                let tSelected = CGFloat(selectedIndex) / CGFloat(moods.count - 1)
                BezierArc(p0: sp0, pc: spc, p1: sp1, tStart: -trackExtend, tEnd: tSelected)
                    .stroke(DesignColors.accentWarm, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .animation(.appBalanced, value: selectedIndex)

                // --- Emoji markers ---
                ForEach(0..<moods.count, id: \.self) { i in
                    let t = CGFloat(i) / CGFloat(moods.count - 1)
                    let pos = bezierPoint(t: t, p0: sp0, pc: spc, p1: sp1)
                    let normal = bezierNormal(t: t, p0: sp0, pc: spc, p1: sp1)
                    let isActive = i <= selectedIndex
                    let isCurrent = i == selectedIndex

                    VStack(spacing: 2) {
                        Text(moods[i].emoji)
                            .font(.system(size: isCurrent ? 30 : 24))
                        Text(moods[i].label)
                            .font(.raleway("Medium", size: isCurrent ? 13 : 11, relativeTo: .caption))
                            .foregroundStyle(isActive ? DesignColors.text : DesignColors.textPlaceholder)
                    }
                    .position(x: pos.x + normal.dx * 40, y: pos.y + normal.dy * 40)
                    .animation(.appBalanced, value: selectedIndex)
                }

                // --- Draggable handle (rounded square, white border) ---
                let ht = CGFloat(selectedIndex) / CGFloat(moods.count - 1)
                let handlePos = bezierPoint(t: ht, p0: sp0, pc: spc, p1: sp1)

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignColors.accentWarm)
                    .frame(width: 52, height: 52)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white, lineWidth: 4)
                    }
                    .overlay {
                        Image(systemName: "arrow.left.and.line.vertical.and.arrow.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: DesignColors.accentWarm.opacity(0.35), radius: 16, x: 0, y: 6)
                    .scaleEffect(isDragging ? 1.08 : 1.0)
                    .position(x: handlePos.x, y: handlePos.y)
                    .animation(.appBalanced, value: selectedIndex)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isDragging)
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                onDragStarted()
                                let idx = closestMoodIndex(to: value.location,
                                                           p0: sp0, pc: spc, p1: sp1)
                                onDragChanged(idx)
                            }
                            .onEnded { _ in onDragEnded() }
                    )

                // --- Big number + label (bottom-right) ---
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(selectedIndex + 1)")
                        .font(.raleway("ExtraBold", size: 160, relativeTo: .title))
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(DesignColors.text)
                        .contentTransition(.numericText())
                        .animation(.appBalanced, value: selectedIndex)

                    Text(moods[selectedIndex].label)
                        .font(.raleway("Bold", size: 30, relativeTo: .title))
                        .foregroundStyle(DesignColors.textSecondary)
                        .contentTransition(.interpolate)
                        .animation(.appBalanced, value: selectedIndex)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 20)
                .padding(.bottom, 16)
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                let idx = closestMoodIndex(to: location, p0: sp0, pc: spc, p1: sp1)
                onDragChanged(idx)
            }
        }
    }

    // MARK: - Bézier math

    /// Quadratic Bézier point at parameter t.
    private func bezierPoint(t: CGFloat, p0: CGPoint, pc: CGPoint, p1: CGPoint) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * p0.x + 2 * u * t * pc.x + t * t * p1.x,
            y: u * u * p0.y + 2 * u * t * pc.y + t * t * p1.y
        )
    }

    /// Outward normal at parameter t (points to the LEFT of the curve direction).
    private func bezierNormal(t: CGFloat, p0: CGPoint, pc: CGPoint, p1: CGPoint) -> (dx: CGFloat, dy: CGFloat) {
        // Tangent = derivative of quadratic bezier
        let u = 1 - t
        let tx = 2 * u * (pc.x - p0.x) + 2 * t * (p1.x - pc.x)
        let ty = 2 * u * (pc.y - p0.y) + 2 * t * (p1.y - pc.y)
        let len = sqrt(tx * tx + ty * ty)
        guard len > 0.001 else { return (0, 0) }
        // Normal perpendicular to tangent, pointing left of travel direction
        return (dx: ty / len, dy: -tx / len)
    }

    /// Find the mood index (0-4) whose curve position is closest to the given point.
    private func closestMoodIndex(to point: CGPoint, p0: CGPoint, pc: CGPoint, p1: CGPoint) -> Int {
        var best = 0
        var bestDist: CGFloat = .infinity
        for i in 0..<moods.count {
            let t = CGFloat(i) / CGFloat(moods.count - 1)
            let p = bezierPoint(t: t, p0: p0, pc: pc, p1: p1)
            let dx = point.x - p.x
            let dy = point.y - p.y
            let dist = dx * dx + dy * dy
            if dist < bestDist {
                bestDist = dist
                best = i
            }
        }
        return best
    }
}

// MARK: - Bézier Arc Shape

/// Draws a quadratic Bézier curve segment from tStart to tEnd.
private struct BezierArc: Shape {
    let p0: CGPoint
    let pc: CGPoint
    let p1: CGPoint
    var tStart: CGFloat
    var tEnd: CGFloat

    var animatableData: CGFloat {
        get { tEnd }
        set { tEnd = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let steps = 60
        var path = Path()
        for i in 0...steps {
            let t = tStart + (tEnd - tStart) * CGFloat(i) / CGFloat(steps)
            let u = 1 - t
            let x = u * u * p0.x + 2 * u * t * pc.x + t * t * p1.x
            let y = u * u * p0.y + 2 * u * t * pc.y + t * t * p1.y
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}
