// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SafeSweep",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "SafeSweep", path: "Sources/SafeSweep"),
        .testTarget(name: "SafeSweepTests", dependencies: ["SafeSweep"], path: "Tests/SafeSweepTests"),
    ]
)
