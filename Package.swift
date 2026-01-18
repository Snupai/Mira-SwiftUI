// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mira",
    platforms: [
        .macOS(.v14)
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
        )
    ]
)
