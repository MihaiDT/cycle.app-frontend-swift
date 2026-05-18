import ComposableArchitecture
import SwiftUI

// MARK: - CycleLengthEditorView
//
// Sub-screen pushed from EditCycleView (the menu). Lets the user
// choose Recommended (auto-mean) vs Manual (pinned). In Manual mode
// the stepper shows below — in Recommended mode the current average
// is shown read-only.

public struct CycleLengthEditorView: View {
    @Bindable var store: StoreOf<CycleLengthEditorFeature>
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<CycleLengthEditorFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppLayout.spacingL) {
                    modeCard
                    modeDescription
                    valueCard
                    if store.mode == .manual {
                        manualHint
                    }
                    Spacer(minLength: AppLayout.spacingXXL)
                }
                .padding(.horizontal, AppLayout.screenHorizontal)
                .padding(.top, AppLayout.spacingM)
            }
            .scrollIndicators(.hidden)

            VStack {
                Spacer()
                saveButton
                    .padding(.horizontal, AppLayout.screenHorizontal)
                    .padding(.bottom, AppLayout.spacingM)
            }



        }
        .navigationBarBackButtonHidden(true)
        .animation(.easeInOut(duration: 0.25), value: store.isSaving)
        .navigationTitle("Cycle length")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DesignColors.text)
                }
                .accessibilityLabel("Back")
                .disabled(store.isSaving)
            }
            ToolbarItem(placement: .principal) {
                Text("Cycle length")
                    .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                    .foregroundStyle(DesignColors.text)
            }
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Cards

    private var modeCard: some View {
        sectionCard(title: "Predictions") {
            VStack(spacing: 0) {
                modeRow(
                    .recommended,
                    label: "Recommended",
                    hint: "Calculated from your past cycles"
                )
                divider
                modeRow(
                    .manual,
                    label: "Manual",
                    hint: "Pin to a fixed value"
                )
            }
        }
    }

    private var modeDescription: some View {
        VStack(alignment: .leading, spacing: AppLayout.spacingS) {
            Text("Recommended keeps your cycle length in sync with the periods you log. It shifts as your rhythm shifts.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(DesignColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Manual locks in a value you choose. Predictions will stay anchored to that number, no matter what future cycles show.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(DesignColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppLayout.spacingXS)
    }

    private var manualHint: some View {
        Text("Your last few cycles average \(store.computedValue) days. Pick whatever feels closest to your usual rhythm.")
            .font(AppTypography.bodyMedium)
            .foregroundStyle(DesignColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppLayout.spacingXS)
    }

    private var valueCard: some View {
        sectionCard(title: store.mode == .manual ? "Your cycle length" : "Current average") {
            switch store.mode {
            case .recommended:
                HStack {
                    Text("Average from your cycles")
                        .font(.raleway("Medium", size: 17, relativeTo: .headline))
                        .foregroundStyle(DesignColors.text)
                    Spacer()
                    Text("\(store.computedValue) days")
                        .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                        .foregroundStyle(DesignColors.textSecondary)
                }
                .padding(.horizontal, AppLayout.spacingM)
                .padding(.vertical, AppLayout.spacingM)

            case .manual:
                Picker(
                    "Cycle length",
                    selection: Binding(
                        get: { store.manualValue },
                        set: { store.send(.manualValueChanged($0)) }
                    )
                ) {
                    ForEach(10...90, id: \.self) { day in
                        Text("\(day) days").tag(day)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 180)
                .padding(.horizontal, AppLayout.spacingS)
            }
        }
    }

    // MARK: - Rows

    private func modeRow(
        _ mode: CycleLengthEditorFeature.Mode,
        label: String,
        hint: String
    ) -> some View {
        Button {
            store.send(.modeChanged(mode))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.raleway("Medium", size: 17, relativeTo: .headline))
                        .foregroundStyle(DesignColors.text)
                    Text(hint)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(DesignColors.textSecondary)
                }
                Spacer()
                if store.mode == mode {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignColors.accentWarm)
                }
            }
            .padding(.horizontal, AppLayout.spacingM)
            .padding(.vertical, AppLayout.spacingM)
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

    private var saveButtonLabel: String {
        if store.isSaving { return "Saving" }
        switch store.mode {
        case .manual: return "Save \(store.manualValue) days"
        case .recommended: return "Use recommended (\(store.computedValue) days)"
        }
    }

    private var saveButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            store.send(.saveTapped)
        } label: {
            HStack(spacing: AppLayout.spacingS) {
                if store.isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .controlSize(.small)
                        .transition(.scale.combined(with: .opacity))
                }
                Text(saveButtonLabel)
                    .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(DesignColors.accentWarm.opacity(store.isSaving ? 0.75 : 1.0))
            )
            .animation(.easeInOut(duration: 0.2), value: store.isSaving)
        }
        .buttonStyle(.plain)
        .disabled(store.isSaving)
    }

    private func sectionCard<Content: View>(
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
