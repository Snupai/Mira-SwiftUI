// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mira",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "Mira", targets: ["Mira"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Mira",
            dependencies: [],
            path: "Sources/Mira",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
