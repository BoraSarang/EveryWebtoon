// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EveryWebtoon",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "EveryWebtoon",
            path: "Sources/EveryWebtoon",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .define("DEBUG", .when(configuration: .debug))
            ]
        )
    ]
)
