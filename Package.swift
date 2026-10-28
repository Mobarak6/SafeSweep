// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StorageCleaner",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "StorageCleaner", path: "Sources/StorageCleaner"),
        .testTarget(name: "StorageCleanerTests", dependencies: ["StorageCleaner"], path: "Tests/StorageCleanerTests"),
    ]
)
