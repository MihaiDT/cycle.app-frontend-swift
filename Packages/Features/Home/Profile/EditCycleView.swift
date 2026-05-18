import ComposableArchitecture
import SwiftUI

// MARK: - EditCycleView (menu)
//
// Cycle data menu pushed from ProfileView. Shows two rows with their
// current values; each pushes a dedicated editor screen. Matches the
// Clue "Personalize cycle" pattern: top-level summary + drill-down.

public struct EditCycleView: View {
    @Bindable var store: StoreOf<EditCycleFeature>

    public init(store: StoreOf<EditCycleFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppLayout.spacingL) {
                    predictionsSection
                    displaySection
                }
                .padding(.horizontal, AppLayout.screenHorizontal)
                .padding(.top, AppLayout.spacingM)
                .padding(.bottom, AppLayout.spacingXXL)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Cycle data")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Cycle data")
                    .font(AppTypography.rowTitleEmphasized)
                    .foregroundStyle(DesignColors.text)
            }
        }
        .navigationDestination(
            item: $store.scope(state: \.cycleLengthEditor, action: \.cycleLengthEditor)
        ) { editorStore in
            CycleLengthEditorView(store: editorStore)
        }
        .navigationDestination(
            item: $store.scope(state: \.periodLengthEditor, action: \.periodLengthEditor)
        ) { editorStore in
            PeriodLengthEditorView(store: editorStore)
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Sections

    private var predictionsSection: some View {
        section(title: "Predictions") {
            VStack(spacing: 0) {
                Button {
                    store.send(.cycleLengthRowTapped)
                } label: {
                    summaryRow(
                        label: "Cycle length",
                        value: "\(store.cycleLength) days"
                    )
                }
                .buttonStyle(.plain)
                divider
                Button {
                    store.send(.periodLengthRowTapped)
                } label: {
                    summaryRow(
                        label: "Period length",
                        value: "\(store.periodLength) days"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: AppLayout.spacingS) {
            Text("Display".uppercased())
                .font(AppTypography.cardEyebrow)
                .tracking(AppTypography.cardEyebrowTracking)
                .foregroundStyle(DesignColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppLayout.spacingXS)

            VStack(spacing: 0) {
                toggleRow(
                    label: "Show ovulation",
                    isOn: Binding(
                        get: { store.showOvulation },
                        set: { store.send(.showOvulationToggled($0)) }
                    )
                )
                divider
                toggleRow(
                    label: "Show fertile window",
                    isOn: Binding(
                        get: { store.showFertileWindow },
                        set: { store.send(.showFertileWindowToggled($0)) }
                    )
                )
            }
            .frame(maxWidth: .infinity)
            .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)

            Text("The fertile window is the number of days leading up to ovulation, including the potential ovulation day. This is an estimate and should not be used as a method of contraception or conception. We recommend disabling the fertile window if you currently use contraception or hormone-based medication.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(DesignColors.textSecondary)
                .padding(.horizontal, AppLayout.spacingXS)
                .padding(.top, AppLayout.spacingXS)
        }
    }

    // MARK: - Rows

    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(AppTypography.rowTitle)
                .foregroundStyle(DesignColors.text)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(DesignColors.accentSecondary)
        }
        .padding(.horizontal, AppLayout.spacingM)
        .padding(.vertical, AppLayout.spacingM)
        .contentShape(Rectangle())
    }

    private func summaryRow(
        label: String,
        value: String,
        interactive: Bool = true
    ) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(AppTypography.rowTitle)
                .foregroundStyle(DesignColors.text)
            Spacer()
            Text(value)
                .font(AppTypography.rowTitleEmphasized)
                .foregroundStyle(DesignColors.textSecondary)
                .padding(.trailing, AppLayout.spacingM)
            if interactive {
                ProfileNavChip()
            }
        }
        .padding(.horizontal, AppLayout.spacingM)
        .padding(.vertical, AppLayout.spacingM)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignColors.textSecondary.opacity(0.12))
            .frame(height: 0.5)
            .padding(.horizontal, AppLayout.spacingM)
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppLayout.spacingS) {
            Text(title.uppercased())
                .font(AppTypography.cardEyebrow)
                .tracking(AppTypography.cardEyebrowTracking)
                .foregroundStyle(DesignColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppLayout.spacingXS)

            content()
                .frame(maxWidth: .infinity)
                .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
        }
    }
}
