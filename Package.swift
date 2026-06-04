// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pepepe",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Pepepe",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
