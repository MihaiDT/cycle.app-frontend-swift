import SwiftUI

// MARK: - Splash View

public struct SplashView: View {
    public init() {}

    public var body: some View {
        ZStack {
            // Background gradient image
            GeometryReader { geometry in
                Image("SplashBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .accessibilityHidden(true)
            }
            .ignoresSafeArea()

            // Glass card with logo
            GlassLogoCard()
        }
    }
}

#Preview("Splash") {
    SplashView()
}
