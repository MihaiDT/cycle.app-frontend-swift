import ComposableArchitecture
import SwiftUI

// MARK: - Add Bond — Birth Date Step
//
// Third screen of the AddBond flow. Mirrors the Name and BirthTime
// shells (Venn watermark + single blob hero, eyebrow + title + body)
// and uses the same hourglass-style wheel selector as BirthTime —
// three columns here: day, month (short name), year. The custom
// wheel keeps the editorial feel; the system `DatePicker(.wheel)`
// in a sheet reads as too utilitarian against the rest of the flow.

struct AddBondBirthDateView: View {
    @Bindable var store: StoreOf<AddBondFeature>
    let onDismiss: () -> Void

    // Column-local state. Initialised from `store.birthDate` on
    // appear; commits back via `commitDate()` whenever any column
    // changes.
    @State private var day: Int = 1
    @State private var monthIndex: Int = 1
    @State private var year: Int = 1996

    @State private var watermarkIn = false
    @State private var blobIn = false
    @State private var eyebrowIn = false
    @State private var titleIn = false
    @State private var bodyIn = false
    @State private var pickerIn = false
    @State private var buttonIn = false

    private static let monthNames: [String] = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]

    private static let yearRange: ClosedRange<Int> = {
        let current = Calendar.current.component(.year, from: .now)
        return 1900...current
    }()

    /// Days available in the currently selected (year, month). Drives
    /// the day column's `values` array and the clamp logic in the
    /// month/year `onChange` handlers — without it, picking Feb after
    /// the day was set to 30 would render a row that produces an
    /// invalid date on commit.
    private var daysInSelectedMonth: Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = monthIndex
        let cal = Calendar.current
        guard
            let firstOfMonth = cal.date(from: comps),
            let range = cal.range(of: .day, in: .month, for: firstOfMonth)
        else { return 31 }
        return range.count
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 72)

            heroBlock

            Spacer(minLength: 14)

            textBlock

            Spacer(minLength: 18)

            picker

            Spacer(minLength: 0)

            continueButton
                .padding(.bottom, 24)
        }
        .padding(.horizontal, AppLayout.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            let comps = Calendar.current.dateComponents(
                [.day, .month, .year], from: store.birthDate
            )
            day = comps.day ?? 1
            monthIndex = comps.month ?? 1
            year = comps.year ?? 1996
            animateIn()
        }
        .onChange(of: day) { _, _ in commitDate() }
        .onChange(of: monthIndex) { _, _ in
            if day > daysInSelectedMonth { day = daysInSelectedMonth }
            commitDate()
        }
        .onChange(of: year) { _, _ in
            if day > daysInSelectedMonth { day = daysInSelectedMonth }
            commitDate()
        }
    }

    // MARK: - Hero

    private var heroBlock: some View {
        ZStack {
            VennCirclesWatermark(
                strokeColor: DesignColors.accentWarm,
                lineWidth: 1.6,
                opacity: 0.14,
                circleSize: 180,
                overlap: 74
            )
            .scaleEffect(watermarkIn ? 1.0 : 0.94)
            .opacity(watermarkIn ? 1 : 0)

            Image("BondBlobEmpty")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 132, height: 132)
                .rotationEffect(.degrees(140))
                .birthDateBreathing(enabled: true)
                .scaleEffect(blobIn ? 1.0 : 0.86)
                .opacity(blobIn ? 1 : 0)
        }
        .frame(height: 180)
    }

    // MARK: - Text

    private var textBlock: some View {
        VStack(spacing: 0) {
            Text("Their birthday")
                .font(.raleway("SemiBold", size: 12, relativeTo: .caption2))
                .tracking(1.4)
                .foregroundStyle(DesignColors.textSecondary)
                .textCase(.uppercase)
                .opacity(eyebrowIn ? 1 : 0)
                .offset(y: eyebrowIn ? 0 : 10)

            Text("When were\nthey born?")
                .font(AppTypography.displayHeader)
                .tracking(-0.5)
                .foregroundStyle(DesignColors.textPrincipal)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 10)
                .opacity(titleIn ? 1 : 0)
                .offset(y: titleIn ? 0 : 12)

            Text("Roll the day, month, and year of their arrival.")
                .font(.raleway("Medium", size: 14, relativeTo: .body))
                .tracking(0.1)
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .padding(.horizontal, 4)
                .opacity(bodyIn ? 1 : 0)
                .offset(y: bodyIn ? 0 : 10)
        }
    }

    // MARK: - Picker

    private var picker: some View {
        HStack(spacing: 6) {
            BondDateWheelColumn(
                values: Array(1...daysInSelectedMonth),
                selected: $day,
                formatter: { String(format: "%02d", $0) }
            )
            .frame(width: 64)

            BondDateWheelColumn(
                values: Array(1...12),
                selected: $monthIndex,
                formatter: { Self.monthNames[$0 - 1] }
            )
            .frame(width: 84)

            BondDateWheelColumn(
                values: Array(Self.yearRange),
                selected: $year,
                formatter: { String($0) }
            )
            .frame(width: 100)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .opacity(pickerIn ? 1 : 0)
        .offset(y: pickerIn ? 0 : 14)
    }

    // MARK: - CTA

    private var continueButton: some View {
        WarmCapsuleButton(
            "Continue",
            prominence: .primary,
            isFullWidth: false
        ) {
            store.send(.birthDateContinueTapped)
        }
        .opacity(buttonIn ? 1 : 0)
        .scaleEffect(buttonIn ? 1.0 : 0.94)
    }

    // MARK: - Behaviour

    private func commitDate() {
        var comps = DateComponents()
        comps.year = year
        comps.month = monthIndex
        comps.day = min(day, daysInSelectedMonth)
        guard let newDate = Calendar.current.date(from: comps) else { return }
        store.birthDate = newDate
    }

    // MARK: - Entrance animation

    private func animateIn() {
        withAnimation(.easeOut(duration: 1.0)) { watermarkIn = true }
        withAnimation(.spring(response: 0.85, dampingFraction: 0.82).delay(0.15)) {
            blobIn = true
        }
        withAnimation(.easeOut(duration: 0.65).delay(0.32)) { eyebrowIn = true }
        withAnimation(.easeOut(duration: 0.7).delay(0.44)) { titleIn = true }
        withAnimation(.easeOut(duration: 0.65).delay(0.56)) { bodyIn = true }
        withAnimation(.easeOut(duration: 0.7).delay(0.7)) { pickerIn = true }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.92)) {
            buttonIn = true
        }
    }
}

// MARK: - Bond Date Wheel Column
//
// Generic Int-valued scroll column with a custom string formatter,
// so the same component renders "01..31" for day, "Jan..Dec" for
// month, and "1900..2026" for year. Same scale/opacity/blur falloff
// and edge fade-mask as the time picker — both screens share the
// hourglass silhouette without sharing code yet (kept inline so the
// file stays self-contained while we're iterating on the flow).

private struct BondDateWheelColumn: View {
    let values: [Int]
    @Binding var selected: Int
    let formatter: (Int) -> String

    private let rowHeight: CGFloat = 44
    private var visibleRows: Int { 5 }
    private var visibleHeight: CGFloat { CGFloat(visibleRows) * rowHeight }
    private var sideMargin: CGFloat { (visibleHeight - rowHeight) / 2 }

    private var positionBinding: Binding<Int?> {
        Binding(
            get: { selected },
            set: { newValue in
                if let v = newValue, v != selected { selected = v }
            }
        )
    }

    var body: some View {
        ZStack {
            // Liquid-glass capsule behind the centre row — the
            // selected value visually rests on glass while the
            // rest of the wheel scrolls past it. `nativeGlass`
            // picks up iOS 26's `.glassEffect` for real Liquid
            // Glass and falls back to `.ultraThinMaterial` + rim
            // on iOS 17–25.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: rowHeight)
                .nativeGlass(in: Capsule(), interactive: false)
                .allowsHitTesting(false)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(values, id: \.self) { value in
                        Text(formatter(value))
                            .font(.system(size: 30, weight: .regular, design: .default))
                            .foregroundStyle(DesignColors.textPrincipal)
                            .frame(height: rowHeight)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .scrollTransition(.interactive, axis: .vertical) { content, phase in
                                let d = min(abs(phase.value), 2.0)
                                return content
                                    .opacity(1 - d * 0.36)
                                    .scaleEffect(1 - d * 0.34)
                                    .blur(radius: d * 0.6)
                            }
                            .id(value)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.vertical, sideMargin, for: .scrollContent)
            .scrollPosition(id: positionBinding, anchor: .center)
            // Native picker tick — fires as each value snaps under
            // the centre anchor while the user is scrolling. The
            // same modifier sits on each column (day / month / year
            // each declare their own `selected` binding), so the
            // feedback feels identical to a stock `Picker(.wheel)`.
            .sensoryFeedback(.selection, trigger: selected)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.28),
                        .init(color: .black, location: 0.72),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(height: visibleHeight)
    }
}

// MARK: - Subtle breathing modifier (file-local copy)

private struct BirthDateBreathingModifier: ViewModifier {
    let enabled: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 + (enabled ? phase : 0))
            .onAppear {
                guard enabled else { return }
                withAnimation(
                    .easeInOut(duration: 3.4).repeatForever(autoreverses: true)
                ) {
                    phase = 0.015
                }
            }
    }
}

private extension View {
    func birthDateBreathing(enabled: Bool) -> some View {
        modifier(BirthDateBreathingModifier(enabled: enabled))
    }
}

#Preview {
    AddBondView(
        store: .init(initialState: AddBondFeature.State(step: .birthDate)) {
            AddBondFeature()
        },
        onDismiss: {}
    )
}
