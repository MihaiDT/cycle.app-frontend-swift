import ComposableArchitecture
import SwiftUI

// MARK: - Lens Feature

@Reducer
public struct LensFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var report: AstrologyReport?
        public var isLoading: Bool = false
        public var error: String?
        public var hasAppeared: Bool = false
        public var selectedTab: LensTab = .today

        public enum LensTab: Int, Equatable, Sendable, CaseIterable {
            case today = 0
            case birthChart = 1

            var title: String {
                switch self {
                case .today: "Today"
                case .birthChart: "Birth Chart"
                }
            }
        }

        public init() {}
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case onAppear
        case loadReport
        case reportLoaded(Result<AstrologyReport, Error>)
    }

    @Dependency(\.astrologyLocal) var astrologyLocal
    @Dependency(\.menstrualLocal) var menstrualLocal

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                guard !state.hasAppeared else { return .none }
                state.hasAppeared = true
                return .send(.loadReport)

            case .loadReport:
                state.isLoading = true
                state.error = nil
                return .run { [astrologyLocal, menstrualLocal] send in
                    do {
                        let status = try await menstrualLocal.getStatus()
                        let cycleDay = status.currentCycle.cycleDay
                        let phaseString = status.currentCycle.phase
                        let phase = CyclePhase(rawValue: phaseString) ?? .follicular
                        let report = try await astrologyLocal.generateDailyReport(Date(), cycleDay, phase)
                        await send(.reportLoaded(.success(report)))
                    } catch {
                        await send(.reportLoaded(.failure(error)))
                    }
                }

            case .reportLoaded(.success(let report)):
                state.isLoading = false
                state.report = report
                return .none

            case .reportLoaded(.failure(let error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none
            }
        }
    }
}

// MARK: - Lens View

struct LensView: View {
    @Bindable var store: StoreOf<LensFeature>
    @Namespace private var ns

    var body: some View {
        ZStack {
            DesignColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 24) {
                    Text("Lens")
                        .font(.custom("Raleway-Bold", size: 34))
                        .foregroundStyle(DesignColors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    // Tab toggle
                    tabBar
                        .padding(.horizontal, 24)
                }

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if store.isLoading {
                            loadingState
                        } else if let error = store.error {
                            errorState(error)
                        } else if let report = store.report {
                            switch store.selectedTab {
                            case .today:
                                todayTab(report)
                            case .birthChart:
                                birthChartTab(report)
                            }
                        } else {
                            emptyState
                        }
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 100)
                }
            }
        }
        .task { store.send(.onAppear) }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(LensFeature.State.LensTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        store.selectedTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.custom("Raleway-SemiBold", size: 15))
                        .foregroundStyle(store.selectedTab == tab ? DesignColors.text : DesignColors.textPlaceholder)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            if store.selectedTab == tab {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                                    .matchedGeometryEffect(id: "tab", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(DesignColors.structure.opacity(0.2))
        }
    }

    // MARK: - Today Tab

    @ViewBuilder
    private func todayTab(_ report: AstrologyReport) -> some View {
        let sky = report.dailySky
        let transits = report.personalTransits

        // Moon
        VStack(spacing: 6) {
            Text(sky.moonPhase.type.rawValue)
                .font(.custom("Raleway-Bold", size: 28))
                .foregroundStyle(DesignColors.text)

            let pct = Int(sky.moonPhase.illuminationPct)
            Text("\(pct)% illuminated")
                .font(.custom("Raleway-Regular", size: 15))
                .foregroundStyle(DesignColors.textSecondary)

            if sky.moonPhase.waning {
                Text("Next New Moon \u{2014} \(sky.moonPhase.nextNewMoon)")
                    .font(.custom("Raleway-Regular", size: 13))
                    .foregroundStyle(DesignColors.textPlaceholder)
                    .padding(.top, 2)
            } else {
                Text("Next Full Moon \u{2014} \(sky.moonPhase.nextFullMoon)")
                    .font(.custom("Raleway-Regular", size: 13))
                    .foregroundStyle(DesignColors.textPlaceholder)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [DesignColors.accent.opacity(0.18), DesignColors.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .padding(.horizontal, 24)

        // Status pills
        if sky.voidOfCourse.isVOC || !sky.retrogradePlanets.isEmpty {
            HStack(spacing: 10) {
                if sky.voidOfCourse.isVOC {
                    pill("Void of Course", color: .orange)
                }
                if !sky.retrogradePlanets.isEmpty {
                    let rxText = sky.retrogradePlanets.joined(separator: ", ") + " Rx"
                    pill(rxText, color: .purple)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }

        // Events
        if !sky.specialEvents.all.isEmpty {
            section("Events") {
                ForEach(sky.specialEvents.all, id: \.self) { event in
                    Text(event)
                        .font(.custom("Raleway-Medium", size: 15))
                        .foregroundStyle(DesignColors.text)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(DesignColors.divider.opacity(0.4))
                                .frame(height: 0.5)
                        }
                }
            }
        }

        // Transits
        let allTransits = transits.slowTransits + transits.fastTransits + transits.moonTransits
        if !allTransits.isEmpty {
            section("Transits") {
                ForEach(Array(allTransits.prefix(10).enumerated()), id: \.offset) { _, t in
                    transitRow(t)
                }
            }
        }

        // Chakras
        if !report.chakraActivation.isEmpty {
            section("Chakra") {
                let grouped = Dictionary(grouping: report.chakraActivation, by: \.chakra)
                ForEach(Array(grouped.keys.sorted()), id: \.self) { chakra in
                    chakraRow(chakra: chakra, items: grouped[chakra] ?? [])
                }
            }
        }

        // Overlay
        section("Cycle \u{00D7} Moon") {
            let o = report.cycleMoonOverlay
            VStack(alignment: .leading, spacing: 12) {
                Text(o.result)
                    .font(.custom("Raleway-Medium", size: 16))
                    .foregroundStyle(DesignColors.text)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cycle")
                            .font(.custom("Raleway-Regular", size: 12))
                            .foregroundStyle(DesignColors.textPlaceholder)
                        Text(o.cycleBucket)
                            .font(.custom("Raleway-SemiBold", size: 14))
                            .foregroundStyle(DesignColors.accentWarm)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Moon")
                            .font(.custom("Raleway-Regular", size: 12))
                            .foregroundStyle(DesignColors.textPlaceholder)
                        Text(o.moonBucket)
                            .font(.custom("Raleway-SemiBold", size: 14))
                            .foregroundStyle(DesignColors.accentWarm)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Birth Chart Tab

    @ViewBuilder
    private func birthChartTab(_ report: AstrologyReport) -> some View {
        let natal = report.natalProfile

        // Big 3
        bigThree(natal)

        // Planets
        section("Planets") {
            let sorted = natal.planetPositions.sorted { $0.key < $1.key }
            ForEach(sorted, id: \.key) { name, data in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.custom("Raleway-SemiBold", size: 15))
                            .foregroundStyle(DesignColors.text)
                        let detail = "\(data.sign.name) \(String(format: "%.1f", data.degreeInSign))\u{00B0}  \u{2022}  House \(data.house)"
                        Text(detail)
                            .font(.custom("Raleway-Regular", size: 13))
                            .foregroundStyle(DesignColors.textSecondary)
                    }
                    Spacer()
                    if let d = data.dignity {
                        Text(d.rawValue)
                            .font(.custom("Raleway-Medium", size: 11))
                            .foregroundStyle(dignityColor(d))
                    }
                }
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignColors.divider.opacity(0.3))
                        .frame(height: 0.5)
                }
            }
        }

        // Angles
        section("Angles") {
            ForEach(["Ascendant", "MC", "True Node"], id: \.self) { key in
                if let a = natal.anglesAndNodes[key] {
                    HStack {
                        Text(key)
                            .font(.custom("Raleway-SemiBold", size: 14))
                            .foregroundStyle(DesignColors.text)
                        Spacer()
                        let val = "\(a.sign.name) \(String(format: "%.1f", a.degreeInSign))\u{00B0}"
                        Text(val)
                            .font(.custom("Raleway-Regular", size: 14))
                            .foregroundStyle(DesignColors.textSecondary)
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(DesignColors.divider.opacity(0.3))
                            .frame(height: 0.5)
                    }
                }
            }
        }

        // Houses
        section("Houses") {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(natal.houses, id: \.house) { cusp in
                    HStack(spacing: 8) {
                        let num = "\(cusp.house)"
                        Text(num)
                            .font(.custom("Raleway-Bold", size: 13))
                            .foregroundStyle(DesignColors.accentWarm)
                            .frame(width: 22, alignment: .trailing)
                        let val = "\(cusp.sign.name) \(String(format: "%.0f", cusp.degreeInSign))\u{00B0}"
                        Text(val)
                            .font(.custom("Raleway-Regular", size: 13))
                            .foregroundStyle(DesignColors.textSecondary)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }
        }

        // Aspects
        section("Aspects") {
            ForEach(Array(natal.majorAspects.prefix(12).enumerated()), id: \.offset) { _, asp in
                HStack {
                    let label = "\(asp.planet1) \(asp.aspect.rawValue) \(asp.planet2)"
                    Text(label)
                        .font(.custom("Raleway-Medium", size: 14))
                        .foregroundStyle(DesignColors.text)
                    Spacer()
                    Text(asp.aspect.tone)
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundStyle(toneColor(asp.aspect.tone))
                    let orbStr = "\(String(format: "%.1f", asp.orb))\u{00B0}"
                    Text(orbStr)
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundStyle(DesignColors.textPlaceholder)
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignColors.divider.opacity(0.3))
                        .frame(height: 0.5)
                }
            }
        }

        // Extras
        section("Extras") {
            // Chinese
            VStack(alignment: .leading, spacing: 4) {
                Text("Chinese Zodiac")
                    .font(.custom("Raleway-Regular", size: 12))
                    .foregroundStyle(DesignColors.textPlaceholder)
                let cz = natal.chineseZodiac
                Text("\(cz.element) \(cz.animal)")
                    .font(.custom("Raleway-SemiBold", size: 18))
                    .foregroundStyle(DesignColors.text)
                Text("\(cz.yinYang) \u{2022} \(cz.stem) \u{2022} \(cz.chineseYear)")
                    .font(.custom("Raleway-Regular", size: 13))
                    .foregroundStyle(DesignColors.textSecondary)
            }
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DesignColors.divider.opacity(0.3))
                    .frame(height: 0.5)
            }

            // Life path
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Life Path Number")
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundStyle(DesignColors.textPlaceholder)
                    let isMaster = natal.lifePathNumber == 11 || natal.lifePathNumber == 22 || natal.lifePathNumber == 33
                    if isMaster {
                        Text("Master Number")
                            .font(.custom("Raleway-Medium", size: 13))
                            .foregroundStyle(DesignColors.accentWarm)
                    }
                }
                Spacer()
                let lpStr = "\(natal.lifePathNumber)"
                Text(lpStr)
                    .font(.custom("Raleway-Bold", size: 36))
                    .foregroundStyle(DesignColors.accentWarm)
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - Big Three

    private func bigThree(_ natal: NatalProfile) -> some View {
        let sun = natal.planetPositions["Sun"]
        let moon = natal.planetPositions["Moon"]
        let asc = natal.anglesAndNodes["Ascendant"]

        return VStack(spacing: 28) {
            if let sun {
                bigThreeRow(label: "Sun", sign: sun.sign.name)
            }
            if let moon {
                bigThreeRow(label: "Moon", sign: moon.sign.name)
            }
            if let asc {
                bigThreeRow(label: "Rising", sign: asc.sign.name)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [DesignColors.accent.opacity(0.15), DesignColors.background],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .padding(.horizontal, 24)
    }

    private func bigThreeRow(label: String, sign: String) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.custom("Raleway-Medium", size: 11))
                .foregroundStyle(DesignColors.textPlaceholder)
                .tracking(1.5)
            Text(sign)
                .font(.custom("Raleway-Bold", size: 24))
                .foregroundStyle(DesignColors.text)
        }
    }

    // MARK: - Transit Row

    private func transitRow(_ t: AstroTransitHit) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                let label = "\(t.transitingPlanet) \(t.aspect.rawValue) \(t.natalPlanet)"
                Text(label)
                    .font(.custom("Raleway-SemiBold", size: 14))
                    .foregroundStyle(DesignColors.text)

                HStack(spacing: 8) {
                    Text(t.aspect.tone)
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundStyle(toneColor(t.aspect.tone))
                    if t.transitingRetrograde {
                        Text("retrograde")
                            .font(.custom("Raleway-Regular", size: 12))
                            .foregroundStyle(.purple)
                    }
                }
            }
            Spacer()
            let orbStr = "\(String(format: "%.1f", t.orb))\u{00B0}"
            Text(orbStr)
                .font(.custom("Raleway-Medium", size: 13))
                .foregroundStyle(orbColor(t.orb))
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignColors.divider.opacity(0.3))
                .frame(height: 0.5)
        }
    }

    // MARK: - Chakra Row

    private func chakraRow(chakra: String, items: [AstroChakraActivation]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chakra)
                .font(.custom("Raleway-SemiBold", size: 15))
                .foregroundStyle(DesignColors.text)

            ForEach(Array(items.prefix(3).enumerated()), id: \.offset) { _, item in
                let desc = "\(item.activatedByTransiting) \(item.aspect) \(item.natalTarget) \u{2022} \(item.tone)"
                Text(desc)
                    .font(.custom("Raleway-Regular", size: 13))
                    .foregroundStyle(DesignColors.textSecondary)
            }

            if let theme = items.first?.theme {
                Text(theme)
                    .font(.custom("Raleway-Regular", size: 12))
                    .foregroundStyle(DesignColors.textPlaceholder)
                    .italic()
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignColors.divider.opacity(0.3))
                .frame(height: 0.5)
        }
    }

    // MARK: - Section

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.custom("Raleway-Bold", size: 12))
                .foregroundStyle(DesignColors.textPlaceholder)
                .tracking(1.2)

            content()
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
    }

    // MARK: - Pill

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.custom("Raleway-Medium", size: 12))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(color.opacity(0.1))
            }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(DesignColors.accentWarm)
            Text("Reading the stars...")
                .font(.custom("Raleway-Medium", size: 14))
                .foregroundStyle(DesignColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.custom("Raleway-Regular", size: 14))
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
            Button { store.send(.loadReport) } label: {
                Text("Retry")
                    .font(.custom("Raleway-SemiBold", size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .background { Capsule().fill(DesignColors.accentWarm) }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Set your birth data\nto unlock your cosmic lens")
                .font(.custom("Raleway-Medium", size: 16))
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }

    // MARK: - Helpers

    private func toneColor(_ tone: String) -> Color {
        switch tone {
        case "positive": .green
        case "tension": .orange
        case "intense": .purple
        default: DesignColors.textPlaceholder
        }
    }

    private func orbColor(_ orb: Double) -> Color {
        if orb < 1 { return .green }
        if orb < 2 { return DesignColors.accentWarm }
        return DesignColors.textPlaceholder
    }

    private func dignityColor(_ d: DignityType) -> Color {
        switch d {
        case .domicile, .exaltation, .domicileExaltation: .green
        case .detriment, .fall, .detrimentFall: .orange
        }
    }
}

// MARK: - Preview

#Preview {
    LensView(
        store: .init(initialState: LensFeature.State()) {
            LensFeature()
        }
    )
}
