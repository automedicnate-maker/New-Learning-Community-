// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NewLearningCommunity",
    products: [
        .executable(name: "NewLearningCommunity", targets: ["App"])
    ],
    targets: [
        .executableTarget(
            name: "App",
            path: "Sources",
            resources: [
                .process("Public")
            ]
        )
    ]
)
