import SwiftUI
import UIKit

@main
struct CycleApp: App {
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
