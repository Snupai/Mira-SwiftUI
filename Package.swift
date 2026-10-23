// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Mira",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "Mira", targets: ["Mira"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "Mira",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Mira",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MiraTests",
            dependencies: ["Mira"],
            path: "Tests/MiraTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
