import SwiftUI

// MARK: - Tracking Personalization View
//
// "Customize tracking" — lets the user toggle which
// SymptomCategory tabs appear in the symptom logging sheet and
// drag-reorder them. Reads/writes through TrackingPreferencesStore;
// CalendarSymptomSheet observes the same store so changes here
// flow into the sheet on next presentation.
//
// Pushed onto the Profile NavigationStack — no inner NavigationStack
// here, matching EditProfileView / EditCycleView. List uses the
// plain style with `AppLayout.screenHorizontal` gutters so the
// content lines up with the rest of the Profile surface; drag
// handles stay visible via a persistent `.editMode` environment.

struct TrackingPersonalizationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = TrackingPreferencesStore.shared
    @State private var editMode: EditMode = .active

    var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            content
        }
        .navigationTitle("Customize tracking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .toolbar { backToolbarItem(dismiss: dismiss) }
    }

    // MARK: - Content

    private var content: some View {
        List {
            descriptionBlock
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(
                    EdgeInsets(
                        top: AppLayout.spacingS,
                        leading: AppLayout.screenHorizontal,
                        bottom: AppLayout.spacingM,
                        trailing: AppLayout.screenHorizontal
                    )
                )
                .deleteDisabled(true)
                .moveDisabled(true)

            masterToggleCard
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(
                    EdgeInsets(
                        top: 0,
                        leading: AppLayout.screenHorizontal,
                        bottom: AppLayout.spacingL,
                        trailing: AppLayout.screenHorizontal
                    )
                )
                .deleteDisabled(true)
                .moveDisabled(true)

            ForEach(store.order, id: \.self) { category in
                row(for: category)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(
                        EdgeInsets(
                            top: 4,
                            leading: AppLayout.screenHorizontal,
                            bottom: 4,
                            trailing: AppLayout.screenHorizontal
                        )
                    )
                    .deleteDisabled(true)
            }
            .onMove { from, to in
                var newOrder = store.order
                newOrder.move(fromOffsets: from, toOffset: to)
                store.setOrder(newOrder)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
    }

    // MARK: - Sections

    private var descriptionBlock: some View {
        VStack(alignment: .leading, spacing: AppLayout.spacingS) {
            Text("Turn categories on or off to filter what you log. Press and drag a category to reorder it.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(DesignColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var masterToggleCard: some View {
        Toggle(isOn: masterBinding) {
            Text("All categories")
                .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                .foregroundStyle(DesignColors.text)
        }
        .tint(DesignColors.accentWarm)
        .padding(.horizontal, AppLayout.spacingM)
        .padding(.vertical, 14)
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
    }

    // MARK: - Row

    private func row(for category: SymptomCategory) -> some View {
        HStack(spacing: AppLayout.spacingS) {
            iconDisc(for: category)

            Text(category.rawValue)
                .font(.raleway("Medium", size: 17, relativeTo: .headline))
                .foregroundStyle(DesignColors.text)

            Spacer(minLength: 0)

            Toggle(
                "",
                isOn: Binding(
                    get: { store.isEnabled(category) },
                    set: { store.setEnabled(category, $0) }
                )
            )
            .labelsHidden()
            .tint(DesignColors.accentWarm)
        }
        .padding(.horizontal, AppLayout.spacingM)
        .padding(.vertical, 12)
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
    }

    private func iconDisc(for category: SymptomCategory) -> some View {
        ZStack {
            Circle()
                .fill(category.tintColor)
            Image(systemName: category.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
        }
        .frame(width: 36, height: 36)
    }

    // MARK: - Bindings

    private var masterBinding: Binding<Bool> {
        Binding(
            get: { store.allEnabled },
            set: { store.setAllEnabled($0) }
        )
    }
}
