import FirebaseCore
import SwiftUI
import UIKit

// MARK: - App Delegate for Firebase

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

// MARK: - Main App

@main
struct CycleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // 0xFDFCF7 = DesignColors.background (Ivory Whisper)
    private static let ivoryBackground = UIColor(
        red: 0xFD / 255.0, green: 0xFC / 255.0, blue: 0xF7 / 255.0, alpha: 1
    )

    init() {
        // Match window background to app background (prevents white in safe areas)
        UIWindow.appearance().backgroundColor = Self.ivoryBackground

        // Load InjectionIII bundle for hot reload
        #if DEBUG
            Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
        #endif

        // Debug: Print all available Raleway fonts
        #if DEBUG
            for family in UIFont.familyNames.sorted() {
                if family.contains("Raleway") {
                    print("Family: \(family)")
                    for name in UIFont.fontNames(forFamilyName: family) {
                        print("  - \(name)")
                    }
                }
            }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppView(
                store: .init(initialState: AppFeature.State()) {
                    AppFeature()
                }
            )
        }
    }
}
