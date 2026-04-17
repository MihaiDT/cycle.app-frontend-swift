import HealthKit
import Inject
import SwiftUI

// MARK: - Health Permission View

public struct HealthPermissionView: View {
    @ObserveInjection var inject
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let onConnect: () -> Void
    public let onSkip: () -> Void
    public let onBack: (() -> Void)?

    @State private var isRequestingPermission = false
    @State private var animateIn = false

    public init(
        onConnect: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self.onConnect = onConnect
        self.onSkip = onSkip
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                OnboardingBackground()

                VStack(spacing: 0) {
                    // Header
                    Spacer().frame(height: geometry.safeAreaInsets.top + 16)

                    OnboardingHeader(
                        currentStep: 8,
                        totalSteps: 11,
                        onBack: onBack
                    )

                    Spacer()

                    // Hero illustration - Apple Health style
                    VStack(spacing: 0) {
                        // Health icon
                        Image("HealthIcon", bundle: .main)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .shadow(color: DesignColors.roseTaupe.opacity(0.5), radius: 24, x: 0, y: 12)
                            .scaleEffect(animateIn ? 1 : 0.9)
                            .opacity(animateIn ? 1 : 0)
                            .accessibilityHidden(true)
                    }

                    Spacer()

                    // Title section
                    VStack(spacing: 16) {
                        Text("Connect Apple Health")
                            .font(.raleway("Bold", size: 28, relativeTo: .title))
                            .foregroundColor(DesignColors.text)
                            .multilineTextAlignment(.center)
                            .opacity(animateIn ? 1 : 0)
                            .accessibilityAddTraits(.isHeader)

                        Text("Sync your cycle data for smarter predictions\nand personalized insights")
                            .font(.raleway("Regular", size: 16, relativeTo: .body))
                            .foregroundColor(DesignColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .opacity(animateIn ? 1 : 0)
                    }
                    .padding(.horizontal, 32)

                    Spacer().frame(height: 32)

                    // Benefits list - clean Apple style
                    VStack(alignment: .leading, spacing: 20) {
                        BenefitItem(
                            icon: "waveform.path.ecg",
                            title: "Cycle Predictions",
                            description: "More accurate period and fertility forecasts"
                        )

                        BenefitItem(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Hormone Insights",
                            description: "Understand how your cycle affects energy & mood"
                        )

                        BenefitItem(
                            icon: "arrow.2.squarepath",
                            title: "Automatic Sync",
                            description: "Keep your health data in one place"
                        )
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(DesignColors.background.opacity(0.6))
                    )
                    .padding(.horizontal, 24)
                    .opacity(animateIn ? 1 : 0)

                    Spacer()

                    // Footer
                    VStack(spacing: 16) {
                        // Primary button - glass style
                        if isRequestingPermission {
                            ProgressView()
                                .frame(height: 55)
                                .accessibilityLabel("Requesting permission")
                        } else {
                            GlassButton("Continue", showArrow: false) {
                                requestHealthPermission()
                            }
                            .accessibilityHint("Opens system permission prompt")
                        }

                        // Skip option
                        Button {
                            onSkip()
                        } label: {
                            Text("Not Now")
                                .font(.raleway("Medium", size: 15, relativeTo: .body))
                                .foregroundColor(DesignColors.text)
                        }
                        .disabled(isRequestingPermission)
                        .accessibilityLabel("Skip — set up later")

                        // Privacy note
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .accessibilityHidden(true)
                            Text("Your data stays on your device")
                                .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        }
                        .foregroundColor(DesignColors.text)
                        .accessibilityElement(children: .combine)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + AppLayout.bottomOffset)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6)) {
                animateIn = true
            }
        }
        .enableInjection()
    }

    private func requestHealthPermission() {
        guard HKHealthStore.isHealthDataAvailable() else {
            onConnect()
            return
        }

        isRequestingPermission = true

        let healthStore = HKHealthStore()

        // All relevant health types for cycle tracking and HRV insights
        let typesToRead: Set<HKObjectType> = [
            // Menstrual cycle data
            HKObjectType.categoryType(forIdentifier: .menstrualFlow)!,
            HKObjectType.categoryType(forIdentifier: .intermenstrualBleeding)!,
            HKObjectType.categoryType(forIdentifier: .ovulationTestResult)!,
            HKObjectType.categoryType(forIdentifier: .cervicalMucusQuality)!,
            HKObjectType.categoryType(forIdentifier: .sexualActivity)!,
            HKObjectType.categoryType(forIdentifier: .contraceptive)!,
            HKObjectType.categoryType(forIdentifier: .pregnancy)!,
            HKObjectType.categoryType(forIdentifier: .lactation)!,

            // Symptoms & body signals
            HKObjectType.categoryType(forIdentifier: .abdominalCramps)!,
            HKObjectType.categoryType(forIdentifier: .bloating)!,
            HKObjectType.categoryType(forIdentifier: .breastPain)!,
            HKObjectType.categoryType(forIdentifier: .headache)!,
            HKObjectType.categoryType(forIdentifier: .acne)!,
            HKObjectType.categoryType(forIdentifier: .moodChanges)!,
            HKObjectType.categoryType(forIdentifier: .appetiteChanges)!,
            HKObjectType.categoryType(forIdentifier: .fatigue)!,
            HKObjectType.categoryType(forIdentifier: .pelvicPain)!,
            HKObjectType.categoryType(forIdentifier: .hotFlashes)!,
            HKObjectType.categoryType(forIdentifier: .vaginalDryness)!,
            HKObjectType.categoryType(forIdentifier: .hairLoss)!,
            HKObjectType.categoryType(forIdentifier: .memoryLapse)!,
            HKObjectType.categoryType(forIdentifier: .sleepChanges)!,
            HKObjectType.categoryType(forIdentifier: .nightSweats)!,
            HKObjectType.categoryType(forIdentifier: .chills)!,
            HKObjectType.categoryType(forIdentifier: .dizziness)!,
            HKObjectType.categoryType(forIdentifier: .drySkin)!,

            // Heart & HRV (for hormone pattern detection)
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,

            // Body measurements
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .basalBodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,

            // Sleep & recovery
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,

            // Activity (affects cycle)
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        ]

        // Types we can write back to Health
        let typesToWrite: Set<HKSampleType> = [
            // Menstrual data
            HKObjectType.categoryType(forIdentifier: .menstrualFlow)!,
            HKObjectType.categoryType(forIdentifier: .intermenstrualBleeding)!,
            HKObjectType.categoryType(forIdentifier: .ovulationTestResult)!,
            HKObjectType.categoryType(forIdentifier: .cervicalMucusQuality)!,
            HKObjectType.categoryType(forIdentifier: .sexualActivity)!,

            // Symptoms
            HKObjectType.categoryType(forIdentifier: .abdominalCramps)!,
            HKObjectType.categoryType(forIdentifier: .bloating)!,
            HKObjectType.categoryType(forIdentifier: .breastPain)!,
            HKObjectType.categoryType(forIdentifier: .headache)!,
            HKObjectType.categoryType(forIdentifier: .acne)!,
            HKObjectType.categoryType(forIdentifier: .moodChanges)!,
            HKObjectType.categoryType(forIdentifier: .fatigue)!,

            // Body
            HKObjectType.quantityType(forIdentifier: .basalBodyTemperature)!,
        ]

        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { _, _ in
            DispatchQueue.main.async {
                isRequestingPermission = false
                onConnect()
            }
        }
    }
}

// MARK: - Benefit Item

private struct BenefitItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(DesignColors.accent.opacity(0.3))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(DesignColors.accentWarm)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                    .foregroundColor(DesignColors.text)

                Text(description)
                    .font(.raleway("Regular", size: 14, relativeTo: .body))
                    .foregroundColor(DesignColors.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview("Health Permission") {
    HealthPermissionView(
        onConnect: { },
        onSkip: { },
        onBack: { }
    )
}
