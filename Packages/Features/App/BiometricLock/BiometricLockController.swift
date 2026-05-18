import LocalAuthentication
import SwiftUI

// MARK: - Biometric Lock Controller
//
// Single source of truth for the app-wide Face ID gate. The
// Settings toggle writes `cycle.app.settings.biometricUnlockEnabled`
// into @AppStorage; this controller reads it on init, locks the
// app whenever it enters the background, and runs the LAContext
// prompt to unlock.
//
// Why an ObservableObject rather than per-view @AppStorage:
// - Lock state (`isUnlocked`) is per-session; @AppStorage would
//   leak it across launches.
// - Scene-phase transitions need a stable subject to mutate.
// - The unlock UI and the gate modifier both need to read + drive
//   the same instance.
//
// Apple compliance notes:
// - We call `.deviceOwnerAuthentication`, which falls back to the
//   device passcode if biometrics fail or aren't enrolled. Pure
//   biometric (.deviceOwnerAuthenticationWithBiometrics) would
//   trap users who re-enrolled or removed Face ID.
// - The toggle in Settings prompts auth BEFORE flipping the value
//   so a stolen unlocked phone can't enable the gate behind the
//   user's back. The flow is symmetric — disabling also re-prompts.

@MainActor
public final class BiometricLockController: ObservableObject {

    public static let shared = BiometricLockController()

    /// True when the lock screen should be hidden (user has
    /// authenticated this session, or the feature is off entirely).
    @Published public private(set) var isUnlocked: Bool

    /// Mirrors @AppStorage so non-SwiftUI consumers (this class,
    /// the AppView gate logic) can read the flag without rebuilding
    /// a SwiftUI environment.
    public var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.storageKey)
    }

    public static let storageKey = "cycle.app.settings.biometricUnlockEnabled"

    private init() {
        let enabled = UserDefaults.standard.bool(forKey: Self.storageKey)
        // When the feature is off, treat the app as unlocked
        // permanently so no gate UI shows. When it's on, start
        // locked — the gate triggers the LAContext prompt.
        self.isUnlocked = !enabled
    }

    /// Re-locks the app. Called on scene-phase background and
    /// when the user re-enables the toggle so the next foreground
    /// has to authenticate.
    public func lock() {
        guard isEnabled else { return }
        isUnlocked = false
    }

    /// Force-unlock without an auth prompt. Used only when the
    /// user just disabled the feature in Settings — at that
    /// moment they've already re-authenticated via the Settings
    /// toggle, so re-prompting here would be redundant.
    public func disableAndUnlock() {
        isUnlocked = true
    }

    /// Runs the LAContext prompt. Returns whether the user
    /// authenticated. Safe to call multiple times.
    @discardableResult
    public func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use passcode"

        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            // Device has neither biometrics nor a passcode.
            // Treat as unlocked so the user isn't trapped.
            isUnlocked = true
            return true
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            if success {
                withAnimation(.easeInOut(duration: 0.28)) {
                    isUnlocked = true
                }
                return true
            }
        } catch {
            // User cancelled or biometric failed too many times.
        }
        return false
    }
}
