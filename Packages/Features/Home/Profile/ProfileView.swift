import ComposableArchitecture
import SwiftData
import SwiftUI

// MARK: - Profile View (Me tab — placeholder)
//
// Real Me screen is being built on another branch. This tab only shows
// a single Reset App action that wipes local data and returns to
// onboarding — useful for starting a clean account during development.

public struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>

    #if DEBUG
    @State private var seedStatus: String?
    #endif

    public init(store: StoreOf<ProfileFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            DesignColors.background.ignoresSafeArea()

            VStack(spacing: AppLayout.spacingL) {
                Spacer(minLength: 0)

                VStack(spacing: AppLayout.spacingS) {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(DesignColors.textSecondary)
                        .padding(.bottom, AppLayout.spacingS)

                    Text("Reset app")
                        .font(.raleway("Bold", size: 22, relativeTo: .title2))
                        .foregroundStyle(DesignColors.text)

                    Text("Clears your on-device data and returns to the start. Use this when you want to begin a fresh account.")
                        .font(.raleway("Regular", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(role: .destructive, action: { store.send(.resetAppTapped) }) {
                    Text("Reset app")
                        .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                        .frame(maxWidth: .infinity, minHeight: AppLayout.buttonHeight)
                        .background {
                            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM, style: .continuous)
                                .fill(DesignColors.accentWarm.opacity(0.15))
                        }
                        .foregroundStyle(DesignColors.accentWarm)
                }
                .buttonStyle(.plain)

                #if DEBUG
                debugSeedSection
                #endif

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
        }
        .navigationTitle("Me")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Reset app?",
            isPresented: $store.isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset app", role: .destructive) {
                store.send(.resetConfirmed)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes every cycle, symptom, and check-in on this device. You can't undo this.")
        }
    }
}

#if DEBUG
extension ProfileView {
    /// Dev-only block. Seeds 60 days of `SelfReportRecord` with
    /// values that fluctuate by cycle phase, so the dot rows on
    /// Cycle History (Energy, Mood, Sleep) actually have something
    /// to render. Stripped out of release builds.
    @ViewBuilder
    fileprivate var debugSeedSection: some View {
        VStack(spacing: AppLayout.spacingS) {
            Button {
                Task { await seedSelfReports() }
            } label: {
                Text("Seed 60 days of check-ins")
                    .font(.raleway("Medium", size: 14, relativeTo: .footnote))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DesignColors.text.opacity(0.18), lineWidth: 0.8)
                    }
                    .foregroundStyle(DesignColors.text.opacity(0.7))
            }
            .buttonStyle(.plain)

            if let status = seedStatus {
                Text(status)
                    .font(.raleway("Medium", size: 11, relativeTo: .caption2))
                    .foregroundStyle(DesignColors.textSecondary)
            }
        }
        .padding(.top, AppLayout.spacingL)
    }

    /// Inserts (or upserts) 60 daily self-reports backdated from
    /// today, with energy/mood/stress/sleep nudged by a sine wave on
    /// `dayOffset` so the resulting dot rows actually look like a
    /// rhythm rather than flat lines. Each existing report on the
    /// same day is replaced — safe to tap repeatedly.
    fileprivate func seedSelfReports() async {
        let container = CycleDataStore.shared
        let context = ModelContext(container)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let totalDays = 60
        var inserted = 0

        for offset in 0..<totalDays {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let phase = Double(offset) / Double(totalDays) * .pi * 4 // ~2 cycles
            let energy = clampedLikert(3.0 + sin(phase) * 1.4 + .random(in: -0.3...0.3))
            let mood = clampedLikert(3.0 + sin(phase + 0.6) * 1.2 + .random(in: -0.3...0.3))
            let sleep = clampedLikert(3.5 + cos(phase) * 1.0 + .random(in: -0.4...0.4))
            let stress = clampedLikert(3.0 - sin(phase) * 1.0 + .random(in: -0.3...0.3))

            let descriptor = FetchDescriptor<SelfReportRecord>(
                predicate: #Predicate { $0.reportDate == date }
            )
            if let existing = try? context.fetch(descriptor).first {
                context.delete(existing)
            }
            context.insert(
                SelfReportRecord(
                    reportDate: date,
                    energyLevel: energy,
                    stressLevel: stress,
                    sleepQuality: sleep,
                    moodLevel: mood
                )
            )
            inserted += 1
        }

        try? context.save()
        seedStatus = "Seeded \(inserted) reports. Pull to refresh Cycle Stats."
    }

    fileprivate func clampedLikert(_ value: Double) -> Int {
        max(1, min(5, Int(value.rounded())))
    }
}
#endif

#Preview {
    NavigationStack {
        ProfileView(
            store: .init(initialState: ProfileFeature.State()) {
                ProfileFeature()
            }
        )
    }
}
