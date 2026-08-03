// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Dayline",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Dayline", targets: ["DaylineApp"])
    ],
    targets: [
        .target(
            name: "DaylineCore",
            path: "Sources/DaylineCore"
        ),
        .executableTarget(
            name: "DaylineApp",
            dependencies: ["DaylineCore"],
            path: "Sources/DaylineApp"
        ),
        .testTarget(
            name: "DaylineCoreTests",
            dependencies: ["DaylineCore"],
            path: "Tests/DaylineCoreTests"
        )
    ]
)
