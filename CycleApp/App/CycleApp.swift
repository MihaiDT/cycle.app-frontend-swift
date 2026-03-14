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

    init() {
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
