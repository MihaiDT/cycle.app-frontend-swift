import Inject
import SwiftUI
import UserNotifications

// MARK: - Notification Permission View

public struct NotificationPermissionView: View {
    @ObserveInjection var inject
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let onEnable: (Int, Int) -> Void
    public let onSkip: () -> Void
    public let onBack: (() -> Void)?

    @State private var isRequestingPermission = false
    @State private var animateIn = false
    @State private var selectedHour: Int = 20
    @State private var selectedMinute: Int = 0

    public init(
        onEnable: @escaping (Int, Int) -> Void,
        onSkip: @escaping () -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self.onEnable = onEnable
        self.onSkip = onSkip
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                OnboardingBackground()

                VStack(spacing: 0) {
                    Spacer().frame(height: geometry.safeAreaInsets.top + 16)

                    OnboardingHeader(
                        currentStep: 9,
                        totalSteps: 11,
                        onBack: onBack
                    )

                    Spacer()

                    // Icon
                    Image(systemName: "bell.badge.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 52, height: 52)
                        .foregroundStyle(DesignColors.accentWarm)
                        .symbolRenderingMode(.hierarchical)
                        .scaleEffect(animateIn ? 1 : 0.8)
                        .opacity(animateIn ? 1 : 0)
                        .accessibilityHidden(true)

                    Spacer().frame(height: 28)

                    // Title
                    Text("Daily Check-in")
                        .font(.raleway("Bold", size: 28, relativeTo: .title))
                        .foregroundColor(DesignColors.text)
                        .opacity(animateIn ? 1 : 0)
                        .accessibilityAddTraits(.isHeader)

                    Spacer().frame(height: 12)

                    Text("A daily reminder to log how you feel,\nso your insights stay accurate.")
                        .font(.raleway("Regular", size: 16, relativeTo: .body))
                        .foregroundColor(DesignColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                        .opacity(animateIn ? 1 : 0)

                    Spacer().frame(height: 44)

                    // Time picker — single clean row
                    HStack(spacing: 8) {
                        Text("Remind me at")
                            .font(.raleway("Medium", size: 16, relativeTo: .body))
                            .foregroundColor(DesignColors.text)

                        timePickerView
                    }
                    .opacity(animateIn ? 1 : 0)

                    Spacer()

                    // Buttons
                    VStack(spacing: 16) {
                        if isRequestingPermission {
                            ProgressView()
                                .frame(height: 55)
                                .accessibilityLabel("Requesting permission")
                        } else {
                            GlassButton("Enable Reminders", showArrow: false) {
                                requestNotificationPermission()
                            }
                            .accessibilityHint("Opens system permission prompt")
                        }

                        Button {
                            onSkip()
                        } label: {
                            Text("Not Now")
                                .font(.raleway("Medium", size: 15, relativeTo: .body))
                                .foregroundColor(DesignColors.textSecondary)
                        }
                        .disabled(isRequestingPermission)
                        .accessibilityLabel("Skip — set up later")
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

    @ViewBuilder
    private var timePickerView: some View {
        HStack(spacing: 4) {
            Picker("Hour", selection: $selectedHour) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(String(format: "%02d", hour)).tag(hour)
                }
            }
            .pickerStyle(.menu)
            .tint(DesignColors.accentWarm)
            .accessibilityLabel("Reminder hour")

            Text(":")
                .font(.raleway("Bold", size: 18, relativeTo: .headline))
                .foregroundColor(DesignColors.text)
                .accessibilityHidden(true)

            Picker("Minute", selection: $selectedMinute) {
                ForEach([0, 15, 30, 45], id: \.self) { minute in
                    Text(String(format: "%02d", minute)).tag(minute)
                }
            }
            .pickerStyle(.menu)
            .tint(DesignColors.accentWarm)
            .accessibilityLabel("Reminder minute")
        }
    }

    private func requestNotificationPermission() {
        isRequestingPermission = true

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                isRequestingPermission = false
                onEnable(selectedHour, selectedMinute)
            }
        }
    }
}

// MARK: - Preview

#Preview("Notification Permission") {
    NotificationPermissionView(
        onEnable: { _, _ in },
        onSkip: { },
        onBack: { }
    )
}
