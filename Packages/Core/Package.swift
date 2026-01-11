// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Models", targets: ["Models"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "Utilities", targets: ["Utilities"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "Core",
            dependencies: ["Models", "Networking", "Persistence", "Utilities", "DesignSystem"]
        ),
        .target(
            name: "Models",
            dependencies: [
                .product(name: "Tagged", package: "swift-tagged")
            ],
            path: "Models"
        ),
        .target(
            name: "Networking",
            dependencies: [
                "Models",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Networking"
        ),
        .target(
            name: "Persistence",
            dependencies: [
                "Models",
                "Utilities",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Persistence"
        ),
        .target(
            name: "Utilities",
            dependencies: [],
            path: "Utilities"
        ),
        .target(
            name: "DesignSystem",
            dependencies: [],
            path: "DesignSystem"
        ),
    ]
)
