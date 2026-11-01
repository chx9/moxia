// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Moxia",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Moxia",
            path: "Sources/Moxia",
            resources: [.copy("Resources/Renderer")]
        ),
    ]
)
