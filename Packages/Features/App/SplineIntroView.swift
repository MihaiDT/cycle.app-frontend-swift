import SplineRuntime
import SwiftUI

// MARK: - Spline Intro View

/// A beautiful 3D animated intro screen using Spline
public struct SplineIntroView: View {
    public let onContinue: () -> Void

    @State private var showContinueButton = false

    private let splineURL = URL(string: "https://build.spline.design/vVoF2gL3Dz4TAALfWBJa/scene.splineswift")!

    public init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Spline 3D Scene - fullscreen for animation
                SplineView(sceneFileURL: splineURL)
                    .ignoresSafeArea()
                    .onAppear {
                        // Show continue button after animation plays
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                showContinueButton = true
                            }
                        }
                    }

                // Continue button overlay
                VStack {
                    Spacer()

                    if showContinueButton {
                        GlassButton("Continue", width: 200) {
                            onContinue()
                        }
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 60)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.easeInOut(duration: 0.5), value: showContinueButton)
            }
        }
    }
}

#Preview("Spline Intro") {
    SplineIntroView {}
}
