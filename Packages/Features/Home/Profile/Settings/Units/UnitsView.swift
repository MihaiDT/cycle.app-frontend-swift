import SwiftUI

// MARK: - Units View
//
// "Units" — pushed from Settings. Currently exposes only the
// temperature unit toggle since that's the lone display unit the
// app actually surfaces (wrist temperature). The shell is sized
// for growth: extra sections (weight, length, glucose, …) drop
// into the same VStack as the app's tracked metrics expand.

struct UnitsView: View {
    @AppStorage(TemperatureUnit.storageKey) private var temperatureRaw: String = TemperatureUnit.celsius.rawValue

    private var selectedTemperature: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureRaw) ?? .celsius
    }

    var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            scrollContent
        }
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppLayout.spacingL) {
                temperatureSection
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.top, AppLayout.spacingS)
            .padding(.bottom, AppLayout.spacingXL)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Sections

    private var temperatureSection: some View {
        VStack(alignment: .leading, spacing: AppLayout.spacingS) {
            sectionLabel("Temperature")
                .padding(.horizontal, AppLayout.spacingXS)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(TemperatureUnit.allCases.enumerated()), id: \.element.rawValue) { index, unit in
                    optionRow(unit: unit)
                    if index < TemperatureUnit.allCases.count - 1 {
                        divider
                    }
                }
            }
            .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)

            Text("Applies to wrist temperature in Body signals. Underlying data stays in Celsius.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(DesignColors.textSecondary)
                .padding(.horizontal, AppLayout.spacingXS)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(AppTypography.cardEyebrow)
            .tracking(AppTypography.cardEyebrowTracking)
            .foregroundStyle(DesignColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Row

    private func optionRow(unit: TemperatureUnit) -> some View {
        Button(action: { select(unit) }) {
            HStack(spacing: AppLayout.spacingS) {
                Text(unit.title)
                    .font(AppTypography.rowTitle)
                    .foregroundStyle(DesignColors.text)

                Spacer(minLength: 0)

                if selectedTemperature == unit {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignColors.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, AppLayout.spacingM)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignColors.textSecondary.opacity(0.12))
            .frame(height: 0.5)
            .padding(.horizontal, AppLayout.spacingM)
    }

    private func select(_ unit: TemperatureUnit) {
        guard temperatureRaw != unit.rawValue else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            temperatureRaw = unit.rawValue
        }
    }
}
