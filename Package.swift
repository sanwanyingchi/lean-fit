// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LeanFitCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LeanFitCore", targets: ["LeanFit"])
    ],
    targets: [
        .target(
            name: "LeanFit",
            path: "LeanFit",
            exclude: [
                "LeanFitApp.swift",
                "Theme.swift",
                "WorkoutFeature.swift",
                "ProgressFeature.swift",
                "ProfileFeature.swift",
                "RecordsFeature.swift",
                "Resources"
            ],
            sources: ["Models.swift", "Engines.swift", "SeedData.swift"]
        ),
        .testTarget(
            name: "LeanFitCoreTests",
            dependencies: ["LeanFit"],
            path: "LeanFitTests"
        )
    ]
)
