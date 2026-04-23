import SwiftUI
import UIKit

// MARK: - UIScrollView offset introspection

private struct ScrollOffsetReaderUIKit: UIViewRepresentable {
    @Binding var offset: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(offset: $offset) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        DispatchQueue.main.async { context.coordinator.attach(from: view) }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async { context.coordinator.attach(from: uiView) }
    }

    final class Coordinator {
        let offset: Binding<CGFloat>
        private var observation: NSKeyValueObservation?

        init(offset: Binding<CGFloat>) {
            self.offset = offset
        }

        func attach(from view: UIView) {
            guard observation == nil else { return }
            var candidate: UIView? = view.superview
            while candidate != nil, !(candidate is UIScrollView) {
                candidate = candidate?.superview
            }
            guard let scrollView = candidate as? UIScrollView else { return }
            observation = scrollView.observe(\.contentOffset, options: [.new]) { [binding = offset] sv, _ in
                let y = sv.contentOffset.y
                DispatchQueue.main.async {
                    binding.wrappedValue = max(0, y)
                }
            }
        }

        deinit { observation?.invalidate() }
    }
}

struct ToDoView: View {
    @State private var items: [ToDoItem] = [
        ToDoItem(
            title: "Morning pages",
            timeRange: "8:00 – 8:30 AM",
            subtitle: "Daily ritual, three pages",
            duration: "30 min",
            friends: [],
            steps: [
                "Grab your notebook and pen",
                "Write three full pages, no editing",
                "Close the notebook, move on with the day"
            ],
            isDone: true
        ),
        ToDoItem(
            title: "Coffee",
            timeRange: "10:30 – 11:15 AM",
            subtitle: "Catch-up, nothing heavy",
            duration: "45 min",
            friends: ["Sofia"],
            steps: [
                "Meet Sofia at the usual place",
                "Order slowly, taste the first sip",
                "Listen more than you talk"
            ]
        ),
        ToDoItem(
            title: "Long walk",
            timeRange: "6:30 – 7:30 PM",
            subtitle: "No phone, slow pace",
            duration: "1 h",
            friends: [],
            steps: [
                "Leave the phone at home or on silent",
                "Walk without a destination for 60 minutes",
                "Notice three things you've never seen before"
            ]
        ),
        ToDoItem(
            title: "Evening call",
            timeRange: "8:00 – 8:30 PM",
            subtitle: "Check-in with the girls",
            duration: "30 min",
            friends: ["Mara", "Elena", "Ioana"],
            steps: [
                "Start the call on time",
                "Go around: one high, one low",
                "Decide on the next get-together"
            ],
            isDone: true
        )
    ]

    @State private var selectedFriend: String?
    @State private var isComposerPresented = false
    @State private var draft: String = ""
    @FocusState private var draftFocused: Bool
    @State private var openedItemID: UUID?
    @State private var scrollOffset: CGFloat = 0
    @State private var isCirclePresented = false
    @State private var selectedCategoryID: String = "mine"
    @AppStorage("todoview.personal_habits") private var personalHabitsJSON: String = "[]"
    @AppStorage("todoview.debug_season") private var debugSeasonRaw: String = "spring"

    private let friends = ["Sofia", "Mara", "Elena", "Ioana", "Ana", "Maria"]

    private var totalItems: Int { items.count }
    private var doneCount: Int { items.filter { $0.isDone }.count }
    private var remaining: Int { totalItems - doneCount }

    private let cream = Color(red: 0.97, green: 0.94, blue: 0.89)
    private let creamDeep = Color(red: 0.94, green: 0.89, blue: 0.82)
    private let cardCream = Color(red: 0.99, green: 0.97, blue: 0.93)
    // Top panel palette — warm sand, deeper hue for clear contrast vs bottom creamDeep
    private let topPeachDeep = Color(red: 0.80, green: 0.71, blue: 0.61)
    private let topPeachMid = Color(red: 0.86, green: 0.78, blue: 0.68)
    private let topPeachLight = Color(red: 0.90, green: 0.83, blue: 0.74)
    // Warm brown ink — softer than pure dark, matches app's warmBrown
    private let ink = Color(red: 0.32, green: 0.25, blue: 0.21)
    private let rust = Color(red: 0.78, green: 0.40, blue: 0.30)
    private let highlightTop = Color(red: 0.96, green: 0.80, blue: 0.52)
    private let highlightBot = Color(red: 0.94, green: 0.72, blue: 0.42)

    private var isStickyVisible: Bool { scrollOffset > 30 }

    var body: some View {
        mainScroll
            .overlay(alignment: .top) {
                compactNavBar
                    .opacity(Double(compactT))
                    .allowsHitTesting(compactT > 0.5)
            }
            .fullScreenCover(isPresented: Binding(
                get: { openedItemID != nil },
                set: { if !$0 { openedItemID = nil } }
            )) {
                if let id = openedItemID,
                   let index = items.firstIndex(where: { $0.id == id }) {
                    detailView(item: $items[index])
                }
            }
            .sheet(isPresented: $isComposerPresented) {
                composer
                    .presentationDetents([.fraction(0.85)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(cream)
                    .presentationCornerRadius(36)
            }
            .sheet(isPresented: $isCirclePresented) {
                circleSheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(cream)
            }
    }

    private var compactT: CGFloat {
        // 0 at rest, 1 when scrolled past greeting (~80pt)
        min(max((scrollOffset - 40) / 40, 0), 1)
    }

    private var bigHeaderOpacity: CGFloat {
        // fades out as user scrolls
        1 - min(max((scrollOffset - 10) / 60, 0), 1)
    }

    private var mainScroll: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                ScrollOffsetReaderUIKit(offset: $scrollOffset)
                    .frame(height: 0)

                VStack(spacing: 14) {
                    topPanel

                    bottomPanel
                        .frame(
                            maxWidth: .infinity,
                            minHeight: proxy.size.height - 200,
                            alignment: .topLeading
                        )
                }
            }
            .background(alignment: .top) {
                topPeachDeep
                    .frame(height: 100)
                    .ignoresSafeArea(edges: .top)
            }
            .background {
                cardCream.ignoresSafeArea()
            }
        }
    }

    private var topPanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerGreeting
                .padding(.horizontal, 26)
                .opacity(Double(bigHeaderOpacity))

            circleSection
        }
        .padding(.top, 4)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 32,
                bottomTrailingRadius: 32,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [topPeachDeep, topPeachMid],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        )
    }

    // MARK: - Compact nav bar

    private var compactNavBar: some View {
        let progress: CGFloat = totalItems > 0 ? CGFloat(doneCount) / CGFloat(totalItems) : 0

        return HStack(alignment: .center, spacing: 18) {
            avatarWithRing(progress: progress)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text("TODAY")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(ink)
                    Circle()
                        .fill(ink.opacity(0.4))
                        .frame(width: 3, height: 3)
                    Text(shortDate.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(ink.opacity(0.6))
                }

                Text(greeting)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 10)

            navTrailing
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 22)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 32,
                bottomTrailingRadius: 32,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [topPeachDeep, topPeachMid],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .ignoresSafeArea(edges: .top)
            .shadow(color: ink.opacity(0.18), radius: 22, x: 0, y: 10)
        )
    }

    @ViewBuilder
    private var navTrailing: some View {
        if totalShared > 0 {
            HStack(spacing: -8) {
                ForEach(allSharedFriends.prefix(3), id: \.self) { name in
                    ZStack {
                        Circle().fill(cardCream).frame(width: 30, height: 30)
                        Circle().strokeBorder(topPeachDeep, lineWidth: 2).frame(width: 30, height: 30)
                        Text(String(name.prefix(1)))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ink)
                    }
                }
                if allSharedFriends.count > 3 {
                    ZStack {
                        Circle().fill(ink).frame(width: 30, height: 30)
                        Circle().strokeBorder(topPeachDeep, lineWidth: 2).frame(width: 30, height: 30)
                        Text("+\(allSharedFriends.count - 3)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(cream)
                    }
                }
            }
        }
    }

    private var allSharedFriends: [String] {
        var names: [String] = []
        for item in items where !item.friends.isEmpty {
            for friend in item.friends where !names.contains(friend) {
                names.append(friend)
            }
        }
        return names
    }

    private func avatarWithRing(progress: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(ink.opacity(0.12), lineWidth: 2.5)
                .frame(width: 54, height: 54)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ink,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 54, height: 54)

            Circle()
                .fill(cardCream)
                .frame(width: 44, height: 44)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(doneCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                Text("/\(totalItems)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.45))
                    .baselineOffset(1)
            }
        }
    }

    private func avatarsInNav(for item: ToDoItem) -> some View {
        HStack(spacing: -6) {
            ForEach(item.friends.prefix(3), id: \.self) { name in
                ZStack {
                    Circle().fill(cream).frame(width: 26, height: 26)
                    Circle().strokeBorder(ink, lineWidth: 2).frame(width: 26, height: 26)
                    Text(String(name.prefix(1)))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ink)
                }
            }
            if item.friends.count > 3 {
                ZStack {
                    Circle().fill(rust).frame(width: 26, height: 26)
                    Circle().strokeBorder(ink, lineWidth: 2).frame(width: 26, height: 26)
                    Text("+\(item.friends.count - 3)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(cream)
                }
            }
        }
    }

    private var doneChip: some View {
        ZStack {
            Circle().fill(rust).frame(width: 30, height: 30)
            Image(systemName: doneCount == totalItems && totalItems > 0 ? "sparkles" : "moon.stars.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(cream)
        }
    }

    // MARK: - Top

    private var totalShared: Int {
        items.filter { !$0.friends.isEmpty }.count
    }

    private var sharedDone: Int {
        items.filter { !$0.friends.isEmpty && $0.isDone }.count
    }

    private var topSection: some View {
        EmptyView()
    }

    private var headerGreeting: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: -4) {
                Text("Good")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(cardCream)
                Text(greetingWord + ".")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(ink)
                    .kerning(-0.6)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text(bigDayNumber)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .kerning(-1.8)
                Text(monthUppercase)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.0)
                    .foregroundStyle(cardCream.opacity(0.85))
                    .padding(.top, -4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greetingWord: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<22: return "evening"
        default: return "night"
        }
    }

    private var greetingPrefix: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Morning,"
        case 12..<17: return "Afternoon,"
        case 17..<22: return "Evening,"
        default: return "Hello,"
        }
    }

    private var monthUppercase: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: Date()).uppercased()
    }

    private var greetingLine: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Morning, Bogdan."
        case 12..<17: return "Afternoon, Bogdan."
        case 17..<22: return "Evening, Bogdan."
        default: return "Hello, Bogdan."
        }
    }

    private var shortMetaLeft: String {
        let f = DateFormatter()
        f.dateFormat = "EEE · d MMM"
        return f.string(from: Date())
    }

    private var progressMeta: String {
        if totalItems == 0 { return "a quiet day" }
        if doneCount == totalItems { return "all done" }
        return "\(doneCount) of \(totalItems) done"
    }

    private var bigDayNumber: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: Date())
    }

    private var longDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: Date())
    }

    // MARK: - Circle section (leaderboard)

    private struct FriendStats: Identifiable {
        let id: String
        var name: String { id }
        let total: Int
        let done: Int
        var progress: CGFloat {
            total > 0 ? CGFloat(done) / CGFloat(total) : 0
        }
        var isWinner: Bool { total > 0 && done == total }
        var hasAny: Bool { total > 0 }
    }

    private var friendStats: [FriendStats] {
        let stats = friends.map { name in
            let total = items.filter { $0.friends.contains(name) }.count
            let done = items.filter { $0.friends.contains(name) && $0.isDone }.count
            return FriendStats(id: name, total: total, done: done)
        }
        // Sort: winners first, then partial done desc, then untouched, then no-shared
        return stats.sorted { a, b in
            if a.isWinner != b.isWinner { return a.isWinner }
            if a.hasAny != b.hasAny { return a.hasAny }
            if a.done != b.done { return a.done > b.done }
            return a.total > b.total
        }
    }

    private var leaderName: String? {
        friendStats.first(where: { $0.isWinner })?.name
    }

    private var circleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CIRCLE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(ink.opacity(0.45))
                    Text(circleHeadline)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(ink)
                }
                Spacer()
                Button {
                    isCirclePresented = true
                } label: {
                    Text("See all")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(cream)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(ink))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 26)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    inviteCard
                    ForEach(friendStats) { stat in
                        friendTile(stat)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 6)
            }
        }
    }

    private var inviteCard: some View {
        Button {} label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("Invite")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ink.opacity(0.55))

                Spacer(minLength: 12)

                HStack(alignment: .firstTextBaseline) {
                    Text("+")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.45))
                    Spacer()
                    Text("add")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ink.opacity(0.45))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().strokeBorder(ink.opacity(0.25), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .frame(minWidth: 156, minHeight: 112, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        ink.opacity(0.25),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func friendTile(_ stat: FriendStats) -> some View {
        let isSelected = selectedFriend == stat.name
        let isWinner = stat.isWinner
        let isActive = stat.hasAny
        let hasProgress = isActive && stat.done > 0

        let bg: Color = {
            if isSelected { return ink }
            if isWinner { return cream }
            return cardCream
        }()
        let textPrimary: Color = isSelected ? cream : ink
        let textSecondary: Color = isSelected ? cream.opacity(0.6) : ink.opacity(0.45)

        let statusText: String = {
            if isWinner { return "done" }
            if hasProgress { return "in progress" }
            if isActive { return "to start" }
            return "idle"
        }()

        return Button {
            selectedFriend = isSelected ? nil : stat.name
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(stat.name)
                    .font(.system(size: isWinner ? 22 : 20, weight: .bold))
                    .foregroundStyle(isActive ? textPrimary : textPrimary.opacity(0.55))
                    .lineLimit(1)

                Spacer(minLength: 12)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if isActive {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(stat.done)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(textPrimary)
                            Text("/\(stat.total)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(textSecondary)
                                .baselineOffset(1)
                        }
                    } else {
                        Text("—")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(textSecondary)
                    }

                    Circle()
                        .fill(textSecondary.opacity(0.5))
                        .frame(width: 3, height: 3)

                    Text(statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(textSecondary)

                    Spacer()
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .frame(minWidth: 156, minHeight: 112, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(bg)
            )
        }
        .buttonStyle(.plain)
    }

    private var circleHeadline: String {
        if let leader = leaderName { return "\(leader) is ahead." }
        if totalShared == 0 { return "No shared tasks today." }
        return "Nobody's done yet."
    }

    private var leaderboardTitle: String { circleHeadline }

    private func fillingOrb(_ stat: FriendStats) -> some View {
        let isSelected = selectedFriend == stat.name
        let isWinner = stat.isWinner
        let isActive = stat.hasAny
        let hasProgress = isActive && stat.done > 0

        let orbSize: CGFloat = {
            if isWinner { return 72 }
            if isActive { return 58 }
            return 50
        }()

        return Button {
            selectedFriend = isSelected ? nil : stat.name
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    // Painterly orb: radial gradient with offset center per friend
                    Circle()
                        .fill(orbGradient(for: stat))
                        .frame(width: orbSize, height: orbSize)

                    // Soft concentric decoration inside
                    Circle()
                        .strokeBorder(ink.opacity(isActive ? 0.07 : 0.04), lineWidth: 1)
                        .frame(width: orbSize * 0.58, height: orbSize * 0.58)

                    // Outer hairline
                    Circle()
                        .strokeBorder(ink.opacity(isActive ? 0.16 : 0.08), lineWidth: 1)
                        .frame(width: orbSize, height: orbSize)

                    // Task segments around the orb
                    if stat.total > 0 {
                        taskSegments(for: stat, aroundOrbSize: orbSize)
                    }

                    if isSelected {
                        Circle()
                            .strokeBorder(ink, lineWidth: 1.5)
                            .frame(width: orbSize + 22, height: orbSize + 22)
                    }
                }
                .frame(width: 92, height: 92)

                VStack(spacing: 4) {
                    Text(stat.name)
                        .font(.system(size: isWinner ? 15 : 13, weight: isWinner ? .bold : .semibold))
                        .foregroundStyle(
                            isWinner ? ink :
                                ink.opacity(isActive ? 0.82 : 0.45)
                        )

                    if isWinner {
                        Text("all done")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ink.opacity(0.6))
                    } else if hasProgress {
                        Text("\(stat.done) of \(stat.total)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ink.opacity(0.55))
                    } else if isActive {
                        Text("0 of \(stat.total)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ink.opacity(0.38))
                    } else {
                        Text("no tasks")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ink.opacity(0.3))
                    }
                }
            }
            .frame(width: 100)
        }
        .buttonStyle(.plain)
    }

    private func taskSegments(for stat: FriendStats, aroundOrbSize orbSize: CGFloat) -> some View {
        let count = stat.total
        let ringSize = orbSize + 12
        let strokeWidth: CGFloat = stat.isWinner ? 3 : 2.5
        let gap: CGFloat = count > 1 ? 0.035 : 0
        let segmentLength: CGFloat = (1.0 - gap * CGFloat(count)) / CGFloat(count)

        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                let start = CGFloat(i) * (segmentLength + gap)
                let end = start + segmentLength
                let isDone = i < stat.done
                Circle()
                    .trim(from: start, to: end)
                    .stroke(
                        isDone ? ink : ink.opacity(0.14),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: ringSize, height: ringSize)
            }
        }
    }

    private func orbGradient(for stat: FriendStats) -> RadialGradient {
        let centers: [UnitPoint] = [
            .topLeading, .top, .topTrailing,
            .bottomLeading, .bottom, .bottomTrailing
        ]
        let idx = abs(stat.name.hashValue) % centers.count
        let center = centers[idx]

        let highlight: Color
        let base: Color
        let shade: Color

        if stat.isWinner {
            highlight = cream
            base = creamDeep
            shade = Color(red: 0.88, green: 0.82, blue: 0.74)
        } else if !stat.hasAny {
            highlight = cardCream
            base = cream
            shade = cream
        } else {
            highlight = cardCream
            base = Color(red: 0.96, green: 0.92, blue: 0.85)
            shade = Color(red: 0.93, green: 0.87, blue: 0.79)
        }

        return RadialGradient(
            colors: [highlight, base, shade],
            center: center,
            startRadius: 2,
            endRadius: 56
        )
    }

    private var inviteOrb: some View {
        Button {} label: {
            VStack(spacing: 14) {
                Circle()
                    .strokeBorder(
                        ink.opacity(0.22),
                        style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])
                    )
                    .frame(width: 58, height: 58)
                    .overlay(
                        Text("+")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(ink.opacity(0.5))
                    )
                    .frame(width: 76, height: 76)
                VStack(spacing: 4) {
                    Text("Invite")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ink.opacity(0.5))
                    Text(" ")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .opacity(0)
                }
            }
            .frame(width: 92)
        }
        .buttonStyle(.plain)
    }

    private func friendOrb(_ stat: FriendStats) -> some View {
        let isSelected = selectedFriend == stat.name

        return Button {
            selectedFriend = isSelected ? nil : stat.name
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    // Track ring
                    Circle()
                        .stroke(ink.opacity(0.1), lineWidth: 2)
                        .frame(width: 64, height: 64)

                    // Progress ring
                    if stat.total > 0 {
                        Circle()
                            .trim(from: 0, to: stat.progress)
                            .stroke(
                                stat.isWinner ? rust : ink.opacity(0.8),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 64, height: 64)
                    }

                    // Orb
                    Circle()
                        .fill(isSelected ? ink : (stat.isWinner ? rust : cardCream))
                        .frame(width: 54, height: 54)
                    Text(String(stat.name.prefix(1)))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            isSelected ? cream :
                                (stat.isWinner ? cream : ink.opacity(stat.hasAny ? 1 : 0.35))
                        )

                    // Winner star
                    if stat.isWinner {
                        ZStack {
                            Circle().fill(rust).frame(width: 20, height: 20)
                            Circle().strokeBorder(cream, lineWidth: 2).frame(width: 20, height: 20)
                            Image(systemName: "sparkles")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(cream)
                        }
                        .offset(x: 22, y: -22)
                    }
                }

                Text(stat.name)
                    .font(.system(size: 12, weight: isSelected || stat.isWinner ? .bold : .medium))
                    .foregroundStyle(
                        isSelected ? ink :
                            (stat.isWinner ? rust : ink.opacity(stat.hasAny ? 0.75 : 0.4))
                    )

                if stat.total > 0 {
                    Text("\(stat.done)/\(stat.total)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(stat.isWinner ? rust : ink.opacity(0.5))
                } else {
                    Text("—")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.3))
                }
            }
            .frame(width: 70)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 16)

            if items.isEmpty {
                emptyState
            } else {
                taskList
            }

            Spacer(minLength: 0)
        }
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 32,
                style: .continuous
            )
            .fill(cream)
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(ink.opacity(0.45))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(remaining)")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(ink)
                    Text(remaining == 1 ? "left" : "left")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(ink.opacity(0.55))
                        .padding(.bottom, 2)
                }
            }
            Spacer()
            newTaskButton
                .padding(.bottom, 4)
        }
    }

    private var newTaskButton: some View {
        Button {
            draft = ""
            isComposerPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("New")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(cream)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(ink)
            )
        }
        .buttonStyle(.plain)
    }

    private var taskList: some View {
        VStack(spacing: 14) {
            ForEach(Array($items.enumerated()), id: \.element.id) { index, $item in
                if index == firstUndoneIndex {
                    highlightCard($item)
                } else {
                    taskCard($item)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 110)
    }

    private var firstUndoneIndex: Int? {
        items.firstIndex(where: { !$0.isDone })
    }

    // MARK: - Highlight card

    private func highlightCard(_ item: Binding<ToDoItem>) -> some View {
        Button {
            openedItemID = item.wrappedValue.id
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(ink.opacity(0.55))
                    Text(item.wrappedValue.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(ink)
                    Text(item.wrappedValue.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(ink.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    item.wrappedValue.isDone = true
                } label: {
                    ZStack {
                        Circle().fill(ink)
                            .frame(width: 42, height: 42)
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(cream)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(highlightBackground)
        }
        .buttonStyle(.plain)
    }

    private var highlightBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [topPeachDeep, topPeachMid],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
    }

    // MARK: - Regular card

    private func taskCard(_ item: Binding<ToDoItem>) -> some View {
        Button {
            openedItemID = item.wrappedValue.id
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(item.wrappedValue.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(ink.opacity(item.wrappedValue.isDone ? 0.35 : 1))
                        .strikethrough(item.wrappedValue.isDone, color: ink.opacity(0.35))
                    Spacer()
                    avatarStack(for: item.wrappedValue)
                }

                Text(item.wrappedValue.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(ink.opacity(0.55))
                    .padding(.top, 4)

                HStack {
                    Spacer()
                    cardActionButton(item)
                }
                .padding(.top, 14)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(cardCream)
            )
        }
        .buttonStyle(.plain)
    }

    private func cardActionButton(_ item: Binding<ToDoItem>) -> some View {
        Button {
            item.wrappedValue.isDone.toggle()
        } label: {
            ZStack {
                Circle()
                    .fill(ink)
                    .frame(width: 36, height: 36)
                Image(systemName: item.wrappedValue.isDone ? "checkmark" : "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(cream)
            }
        }
        .buttonStyle(.plain)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ink.opacity(0.75))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(creamDeep.opacity(0.7))
            )
    }

    private func avatarStack(for item: ToDoItem) -> some View {
        let visible = item.friends.prefix(2)
        let overflow = max(0, item.friends.count - 2)
        return HStack(spacing: -8) {
            ForEach(Array(visible.enumerated()), id: \.offset) { _, name in
                miniOrb(label: String(name.prefix(1)), bg: creamDeep, fg: ink)
            }
            if overflow > 0 {
                miniOrb(label: "+\(overflow)", bg: ink, fg: cream)
            }
        }
    }

    private func miniOrb(label: String, bg: Color, fg: Color) -> some View {
        ZStack {
            Circle().fill(bg)
                .frame(width: 26, height: 26)
            Circle().strokeBorder(cardCream, lineWidth: 2)
                .frame(width: 26, height: 26)
            Text(label)
                .font(.system(size: label.hasPrefix("+") ? 10 : 11, weight: .bold))
                .foregroundStyle(fg)
        }
    }

    private var emptyState: some View {
        Text("A quiet day.")
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(ink.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }

    // MARK: - Detail view

    private func detailView(item: Binding<ToDoItem>) -> some View {
        let isHighlight = items.firstIndex(where: { $0.id == item.wrappedValue.id }) == firstUndoneIndex

        return ZStack(alignment: .top) {
            Group {
                if isHighlight {
                    LinearGradient(
                        colors: [topPeachDeep, topPeachMid],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                } else {
                    cardCream
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                detailNav(item: item.wrappedValue)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        detailHero(item: item.wrappedValue)
                        detailBody(item: item)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            VStack {
                Spacer()
                detailCTA(item: item)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
        }
    }

    private func detailNav(item: ToDoItem) -> some View {
        HStack {
            Button {
                openedItemID = nil
            } label: {
                ZStack {
                    Circle().fill(Color.white.opacity(0.35))
                        .frame(width: 38, height: 38)
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ink)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {} label: {
                ZStack {
                    Circle().fill(Color.white.opacity(0.35))
                        .frame(width: 38, height: 38)
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ink)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private func detailHero(item: ToDoItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(item.title)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Text(item.subtitle)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(ink.opacity(0.7))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }

    private func detailBody(item: Binding<ToDoItem>) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("WHAT TO DO")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(ink.opacity(0.45))
                    .padding(.bottom, 2)

                if item.wrappedValue.steps.isEmpty {
                    Text("No steps yet. Just start.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(ink.opacity(0.55))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.35))
                        )
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(item.wrappedValue.steps.enumerated()), id: \.offset) { idx, step in
                            stepRow(index: idx + 1, text: step)
                        }
                    }
                }
            }

            if !item.wrappedValue.friends.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("WITH")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(ink.opacity(0.45))

                    HStack(spacing: 10) {
                        ForEach(item.wrappedValue.friends, id: \.self) { name in
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle().fill(ink)
                                        .frame(width: 28, height: 28)
                                    Text(String(name.prefix(1)))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(cream)
                                }
                                Text(name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(ink)
                            }
                            .padding(.trailing, 8)
                            .padding(.vertical, 6)
                            .padding(.leading, 6)
                            .background(
                                Capsule().fill(Color.white.opacity(0.35))
                            )
                        }
                    }
                }
            }
        }
    }

    private func stepRow(index: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(ink)
                    .frame(width: 26, height: 26)
                Text("\(index)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(cream)
            }
            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.35))
        )
    }

    private func metaTile(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
            }
            .foregroundStyle(ink.opacity(0.55))

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.35))
        )
    }

    private func detailCTA(item: Binding<ToDoItem>) -> some View {
        Button {
            item.wrappedValue.isDone.toggle()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                openedItemID = nil
            }
        } label: {
            HStack {
                Image(systemName: item.wrappedValue.isDone ? "arrow.uturn.backward" : "checkmark")
                    .font(.system(size: 14, weight: .bold))
                Text(item.wrappedValue.isDone ? "Mark as not done" : "Mark as done")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(cream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(ink)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Circle sheet (see all)

    private var circleSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your circle")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ink)
                Text(circleHeadline)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ink.opacity(0.55))
            }
            .padding(.horizontal, 26)
            .padding(.top, 14)
            .padding(.bottom, 18)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(friendStats.enumerated()), id: \.element.id) { idx, stat in
                        if idx > 0 {
                            Rectangle()
                                .fill(ink.opacity(0.06))
                                .frame(height: 1)
                                .padding(.horizontal, 26)
                        }
                        circleSheetRow(rank: idx + 1, stat: stat)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func circleSheetRow(rank: Int, stat: FriendStats) -> some View {
        let isWinner = stat.isWinner
        let isActive = stat.hasAny
        let hasProgress = isActive && stat.done > 0

        let statusText: String = {
            if isWinner { return "all done" }
            if hasProgress { return "in progress" }
            if isActive { return "nothing yet" }
            return "no tasks"
        }()

        return Button {
            selectedFriend = selectedFriend == stat.name ? nil : stat.name
            isCirclePresented = false
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Text(String(format: "%02d", rank))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? ink.opacity(0.55) : ink.opacity(0.3))
                    .frame(width: 24, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(stat.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isActive ? ink : ink.opacity(0.5))
                    Text(statusText)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(ink.opacity(0.5))
                }

                Spacer()

                if isActive {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(stat.done)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(ink)
                        Text("/\(stat.total)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(ink.opacity(0.5))
                    }
                } else {
                    Text("—")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.3))
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Composer (categorized habit library + custom input)

    private struct HabitCategory: Identifiable, Hashable {
        let id: String
        let title: String
        let eyebrow: String
        let suggestions: [LibrarySuggestion]
    }

    private struct LibrarySuggestion: Identifiable, Hashable, Codable {
        let title: String
        let subtitle: String
        var why: String? = nil
        var id: String { title }
    }

    private enum CycleSeason: String, Codable {
        case winter, spring, summer, fall
    }

    private var currentSeason: CycleSeason {
        CycleSeason(rawValue: debugSeasonRaw) ?? .spring
    }

    private var seasonLabel: String {
        switch currentSeason {
        case .winter: return "Winter season"
        case .spring: return "Spring season"
        case .summer: return "Summer season"
        case .fall:   return "Fall season"
        }
    }

    private var nowEyebrow: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return "FOR THIS SOFT MORNING"
        case 11..<16: return "FOR THIS AFTERNOON"
        case 16..<21: return "FOR THIS EVENING"
        default:      return "PERMISSION FOR TONIGHT"
        }
    }

    private var nowSuggestions: [LibrarySuggestion] {
        let hour = Calendar.current.component(.hour, from: Date())
        let isLuteal = currentSeason == .fall
        let isMenstrual = currentSeason == .winter
        switch hour {
        case 5..<11:
            if isMenstrual {
                return [
                    LibrarySuggestion(title: "Warm tea", subtitle: "Slow and quiet", why: "Cocoon mode. Heat eases cramps gently."),
                    LibrarySuggestion(title: "Soft stretch", subtitle: "Five gentle poses", why: "Light movement helps without taxing you."),
                    LibrarySuggestion(title: "Permission to rest", subtitle: "Listen to your body", why: "Rest is the habit today.")
                ]
            } else if isLuteal {
                return [
                    LibrarySuggestion(title: "Hydrate first", subtitle: "A full glass of water", why: "Bloating eases when you front-load fluids."),
                    LibrarySuggestion(title: "Morning pages", subtitle: "Three honest pages", why: "Catch the noise before it gets louder."),
                    LibrarySuggestion(title: "Long walk", subtitle: "No phone, slow pace", why: "Steady movement steadies the mood.")
                ]
            } else {
                return [
                    LibrarySuggestion(title: "Hydrate", subtitle: "A full glass of water", why: "Anchor it to making coffee."),
                    LibrarySuggestion(title: "Morning yoga", subtitle: "Ten gentle poses", why: "Energy is climbing — moving compounds it."),
                    LibrarySuggestion(title: "Make the bed", subtitle: "A quiet win, early", why: "One done thing rewires the day's tone.")
                ]
            }
        case 11..<16:
            if isLuteal {
                return [
                    LibrarySuggestion(title: "Proper meal", subtitle: "Sit down, no screens", why: "Steady blood sugar = steady mood."),
                    LibrarySuggestion(title: "Easy walk", subtitle: "Just twenty minutes", why: "Light cardio without pushing it."),
                    LibrarySuggestion(title: "Message someone", subtitle: "A thought-of-you text", why: "Cheapest mood lift there is.")
                ]
            } else {
                return [
                    LibrarySuggestion(title: "Long walk", subtitle: "No phone, slow pace", why: "Sun + steps = best afternoon reset."),
                    LibrarySuggestion(title: "Proper meal", subtitle: "Sit down, no screens", why: "Blood sugar drives the rest of your day."),
                    LibrarySuggestion(title: "Deep work, 25 min", subtitle: "One thing, fully", why: "Focus capacity peaks now — use it.")
                ]
            }
        case 16..<21:
            if isLuteal || isMenstrual {
                return [
                    LibrarySuggestion(title: "Cocoon mode", subtitle: "Cozy clothes, dim lights", why: "Lower stimulation now so sleep arrives easier."),
                    LibrarySuggestion(title: "Warm bath", subtitle: "No rush, no phone", why: "Heat + quiet recalibrates the nervous system."),
                    LibrarySuggestion(title: "Read", subtitle: "A few pages, analog", why: "Off-screen wind-down outperforms scrolling.")
                ]
            } else {
                return [
                    LibrarySuggestion(title: "Call a friend", subtitle: "One real conversation", why: "Social warmth drops cortisol."),
                    LibrarySuggestion(title: "Tidy a corner", subtitle: "Just one small space", why: "Tomorrow-you will thank tonight-you."),
                    LibrarySuggestion(title: "Stretch", subtitle: "Head to toe, slow", why: "Releases the day held in your shoulders.")
                ]
            }
        default:
            return [
                LibrarySuggestion(title: "Permission to rest", subtitle: "Lights out early", why: "Sleep is the most under-rated habit there is."),
                LibrarySuggestion(title: "Skincare ritual", subtitle: "The full evening one", why: "Anchors a wind-down routine."),
                LibrarySuggestion(title: "Journal one line", subtitle: "Just how today felt", why: "Tiny habit — small enough to never skip.")
            ]
        }
    }

    private var personalHabits: [LibrarySuggestion] {
        guard let data = personalHabitsJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([LibrarySuggestion].self, from: data) else { return [] }
        return decoded
    }

    private func savePersonalHabit(_ s: LibrarySuggestion) {
        var current = personalHabits
        current.removeAll { $0.title.lowercased() == s.title.lowercased() }
        current.insert(s, at: 0)
        if let data = try? JSONEncoder().encode(current),
           let str = String(data: data, encoding: .utf8) {
            personalHabitsJSON = str
        }
    }

    private func removePersonalHabit(_ s: LibrarySuggestion) {
        var current = personalHabits
        current.removeAll { $0.id == s.id }
        if let data = try? JSONEncoder().encode(current),
           let str = String(data: data, encoding: .utf8) {
            personalHabitsJSON = str
        }
    }

    private var habitCategories: [HabitCategory] {
        [
            HabitCategory(
                id: "mine",
                title: "Mine",
                eyebrow: "YOUR HABITS",
                suggestions: personalHabits
            ),
            HabitCategory(
                id: "move",
                title: "Move",
                eyebrow: "GENTLE OR STRONG, YOUR CALL",
                suggestions: [
                    LibrarySuggestion(title: "Long walk", subtitle: "No phone, slow pace", why: "Anchor it to lunch — habits stick to existing routines."),
                    LibrarySuggestion(title: "Stretch", subtitle: "Loosen up, head to toe", why: "Two minutes counts. Tiny is the point."),
                    LibrarySuggestion(title: "Morning yoga", subtitle: "Ten gentle poses", why: "Sets the nervous system for the day."),
                    LibrarySuggestion(title: "Workout", subtitle: "Move with intention", why: "Listen to today's energy, not the calendar."),
                    LibrarySuggestion(title: "Dance it out", subtitle: "One full song, kitchen floor", why: "Mood follows movement — even three minutes."),
                    LibrarySuggestion(title: "Deep breaths", subtitle: "Five slow rounds", why: "Down-regulates stress in under a minute.")
                ]
            ),
            HabitCategory(
                id: "mind",
                title: "Mind",
                eyebrow: "QUIET INPUT, CLEARER HEAD",
                suggestions: [
                    LibrarySuggestion(title: "Morning pages", subtitle: "Three pages, no editing", why: "Catches the noise before it gets louder."),
                    LibrarySuggestion(title: "Journal", subtitle: "One honest paragraph", why: "You become a person who reflects."),
                    LibrarySuggestion(title: "Meditate", subtitle: "Ten quiet minutes", why: "Even five minutes shifts attention quality."),
                    LibrarySuggestion(title: "Read", subtitle: "A few pages, analog", why: "Off-screen wind-down outperforms scrolling."),
                    LibrarySuggestion(title: "Gratitude note", subtitle: "Three small things", why: "Cheap mood lift, free."),
                    LibrarySuggestion(title: "Screen-free hour", subtitle: "Put the phone away", why: "Boundary > willpower.")
                ]
            ),
            HabitCategory(
                id: "care",
                title: "Care",
                eyebrow: "PERMISSION, NOT PERFORMANCE",
                suggestions: [
                    LibrarySuggestion(title: "Hydrate", subtitle: "A full glass of water", why: "Front-load fluids, especially in luteal week."),
                    LibrarySuggestion(title: "Skincare", subtitle: "The full evening ritual", why: "Anchor a wind-down to a thing you already do."),
                    LibrarySuggestion(title: "Sleep early", subtitle: "Lights out before 11", why: "The most under-rated habit there is."),
                    LibrarySuggestion(title: "Cold shower", subtitle: "Thirty seconds, cold", why: "Resets focus when you can't get going."),
                    LibrarySuggestion(title: "Warm bath", subtitle: "No rush, no phone", why: "Heat + quiet recalibrates the nervous system."),
                    LibrarySuggestion(title: "Proper meal", subtitle: "Sit down, no screens", why: "Steady blood sugar, steady mood.")
                ]
            ),
            HabitCategory(
                id: "connect",
                title: "Connect",
                eyebrow: "WARMTH IN SMALL DOSES",
                suggestions: [
                    LibrarySuggestion(title: "Call a friend", subtitle: "One real conversation", why: "Social warmth drops cortisol."),
                    LibrarySuggestion(title: "Family dinner", subtitle: "Together, at the table", why: "Shared meals are a quiet superpower."),
                    LibrarySuggestion(title: "Message someone", subtitle: "A thought-of-you text", why: "Cheapest connection move there is."),
                    LibrarySuggestion(title: "Coffee date", subtitle: "In person, no rush", why: "Slow time with one beats five group chats."),
                    LibrarySuggestion(title: "Check on mom", subtitle: "Just a quick hi", why: "Two minutes, big return."),
                    LibrarySuggestion(title: "Compliment someone", subtitle: "Out loud, no hedging", why: "Both of you walk away lighter.")
                ]
            ),
            HabitCategory(
                id: "home",
                title: "Home",
                eyebrow: "TINY WINS THAT COMPOUND",
                suggestions: [
                    LibrarySuggestion(title: "Tidy a corner", subtitle: "Just one small space", why: "Small visible win shifts the day's tone."),
                    LibrarySuggestion(title: "Plan tomorrow", subtitle: "Three things, no more", why: "Closes today, opens tomorrow."),
                    LibrarySuggestion(title: "Make the bed", subtitle: "A quiet win, early", why: "First done thing of the day."),
                    LibrarySuggestion(title: "Open the windows", subtitle: "Fresh air, five minutes", why: "Resets the room and your head."),
                    LibrarySuggestion(title: "Empty inbox", subtitle: "Zero unread, zero stress", why: "Less open loops = less background noise."),
                    LibrarySuggestion(title: "Fresh flowers", subtitle: "One small bunch", why: "Beauty in the room costs almost nothing.")
                ]
            )
        ]
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Build your day.")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(ink)
                Text("A personal habit, picked on purpose.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(ink.opacity(0.55))
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)

            composerInputRow
                .padding(.horizontal, 20)

            categoryChips
                .padding(.top, 2)

            ScrollView(showsIndicators: false) {
                let category = selectedComposerCategory
                VStack(alignment: .leading, spacing: 14) {
                    Text(category.eyebrow)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(ink.opacity(0.45))
                        .padding(.horizontal, 24)

                    if category.id == "mine" && category.suggestions.isEmpty {
                        mineEmptyState
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(category.suggestions) { suggestion in
                                libraryTile(suggestion, inMine: category.id == "mine")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .padding(.top, 8)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                draftFocused = true
            }
        }
    }

    private var selectedComposerCategory: HabitCategory {
        habitCategories.first(where: { $0.id == selectedCategoryID }) ?? habitCategories[0]
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(habitCategories) { category in
                    categoryChip(category)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
    }

    private func categoryChip(_ category: HabitCategory) -> some View {
        let isSelected = category.id == selectedCategoryID
        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                selectedCategoryID = category.id
            }
        } label: {
            Text(category.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? cream : ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(isSelected ? ink : cardCream)
                )
        }
        .buttonStyle(.plain)
    }

    private var composerInputRow: some View {
        HStack(spacing: 12) {
            TextField(
                "",
                text: $draft,
                prompt: Text("Write your own habit…")
                    .foregroundColor(ink.opacity(0.4))
            )
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(ink)
            .tint(ink)
            .focused($draftFocused)
            .submitLabel(.done)
            .onSubmit(commitDraft)

            Button(action: commitDraft) {
                ZStack {
                    Circle()
                        .fill(draft.trimmingCharacters(in: .whitespaces).isEmpty ? ink.opacity(0.25) : ink)
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(cream)
                }
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(cardCream)
        )
    }

    private var mineEmptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ink.opacity(0.08))
                    .frame(width: 56, height: 56)
                Image(systemName: "heart")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.55))
            }
            VStack(spacing: 4) {
                Text("Build your own.")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(ink)
                Text("Long-press a habit to save it here, or write your own above.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(ink.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(cardCream)
        )
    }

    private func libraryTile(_ suggestion: LibrarySuggestion, inMine: Bool) -> some View {
        Button {
            addFromLibrary(suggestion)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(suggestion.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                Text(suggestion.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(ink.opacity(0.55))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                HStack(spacing: 0) {
                    if inMine {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(rust.opacity(0.85))
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(ink)
                            .frame(width: 28, height: 28)
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(cream)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(cardCream)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if inMine {
                Button(role: .destructive) {
                    removePersonalHabit(suggestion)
                } label: {
                    Label("Remove from Mine", systemImage: "heart.slash")
                }
            } else {
                Button {
                    savePersonalHabit(suggestion)
                    let gen = UIImpactFeedbackGenerator(style: .soft)
                    gen.impactOccurred()
                } label: {
                    Label("Save to Mine", systemImage: "heart")
                }
            }
        }
    }

    private func addFromLibrary(_ suggestion: LibrarySuggestion) {
        let item = ToDoItem(
            title: suggestion.title,
            timeRange: "",
            subtitle: suggestion.subtitle,
            duration: "",
            friends: [],
            steps: []
        )
        items.append(item)
        savePersonalHabit(suggestion)
        draft = ""
        isComposerPresented = false
    }

    // MARK: - Actions

    private func commitDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = ToDoItem(
            title: trimmed,
            timeRange: "",
            subtitle: "Just added",
            duration: "",
            friends: selectedFriend.map { [$0] } ?? [],
            steps: []
        )
        items.append(item)
        savePersonalHabit(LibrarySuggestion(title: trimmed, subtitle: "Your habit"))
        draft = ""
        isComposerPresented = false
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Morning, Bogdan."
        case 12..<17: return "Afternoon, Bogdan."
        case 17..<22: return "Evening, Bogdan."
        default: return "Hi, Bogdan."
        }
    }

    private var shortDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · d MMM"
        return f.string(from: Date())
    }
}

private struct ToDoItem: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var timeRange: String
    var subtitle: String
    var duration: String
    var friends: [String]
    var steps: [String] = []
    var isDone: Bool = false
}

private struct TodoScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
