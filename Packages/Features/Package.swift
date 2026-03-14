// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Features",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Features", targets: ["Features"]),
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "AuthenticationFeature", targets: ["AuthenticationFeature"]),
        .library(name: "HomeFeature", targets: ["HomeFeature"]),
        .library(name: "OnboardingFeature", targets: ["OnboardingFeature"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.23.0"),
        .package(url: "https://github.com/krzysztofzablocki/Inject", from: "1.5.2"),
        .package(url: "https://github.com/splinetool/spline-ios", from: "0.2.48"),
        .package(url: "https://github.com/airbnb/lottie-ios", from: "4.5.0"),
        .package(path: "../Core"),
    ],
    targets: [
        .target(
            name: "Features",
            dependencies: ["AppFeature", "AuthenticationFeature", "HomeFeature", "OnboardingFeature"]
        ),
        .target(
            name: "AppFeature",
            dependencies: [
                "AuthenticationFeature",
                "HomeFeature",
                "OnboardingFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Inject", package: "Inject"),
                .product(name: "SplineRuntime", package: "spline-ios"),
                .product(name: "Core", package: "Core"),
                .product(name: "DesignSystem", package: "Core"),
            ],
            path: "App"
        ),
        .target(
            name: "AuthenticationFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Inject", package: "Inject"),
                .product(name: "Core", package: "Core"),
            ],
            path: "Authentication"
        ),
        .target(
            name: "HomeFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Inject", package: "Inject"),
                .product(name: "Core", package: "Core"),
            ],
            path: "Home"
        ),
        .target(
            name: "OnboardingFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Inject", package: "Inject"),
                .product(name: "Core", package: "Core"),
                .product(name: "DesignSystem", package: "Core"),
                .product(name: "Lottie", package: "lottie-ios"),
            ],
            path: "Onboarding",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
