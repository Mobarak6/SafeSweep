import SwiftUI

enum Risk {
    /// Rebuilt automatically by the app or tool that owns it.
    case safe
    /// Rebuildable, but costs a re-download or loses something worth a look first.
    case review
    /// Cannot go to the Trash (it *is* the Trash); deleted for good.
    case permanent

    var label: String {
        switch self {
        case .safe: "Safe"
        case .review: "Review"
        case .permanent: "Permanent"
        }
    }

    var color: Color {
        switch self {
        case .safe: .green
        case .review: .orange
        case .permanent: .red
        }
    }
}

struct CleanupDefinition {
    let id: String
    let name: String
    let group: String
    let explanation: String
    let risk: Risk
    /// The individual files/folders this category would remove. Never the parent folder itself.
    let items: () -> [URL]
}

enum CleanupCatalog {
    static let groups = ["System & Apps", "Developer", "Trash"]

    static let all: [CleanupDefinition] = [
        CleanupDefinition(
            id: "user-caches", name: "App & browser caches", group: "System & Apps",
            explanation: "Temporary data in ~/Library/Caches. Apps rebuild it on demand; quit browsers first for best results.",
            risk: .safe
        ) { FileUtils.children(of: FileUtils.url("Library/Caches")) },

        CleanupDefinition(
            id: "user-logs", name: "App logs & crash reports", group: "System & Apps",
            explanation: "Old diagnostic logs in ~/Library/Logs. Only useful when debugging a crash.",
            risk: .safe
        ) { FileUtils.children(of: FileUtils.url("Library/Logs")) },

        CleanupDefinition(
            id: "xcode-derived", name: "Xcode DerivedData", group: "Developer",
            explanation: "Intermediate build products. Xcode rebuilds them; the next build is slower.",
            risk: .safe
        ) { FileUtils.children(of: FileUtils.url("Library/Developer/Xcode/DerivedData")) },

        CleanupDefinition(
            id: "xcode-previews", name: "SwiftUI preview & simulator caches", group: "Developer",
            explanation: "Preview simulators and CoreSimulator caches. Recreated when needed.",
            risk: .safe
        ) {
            FileUtils.children(of: FileUtils.url("Library/Developer/Xcode/UserData/Previews"))
                + FileUtils.children(of: FileUtils.url("Library/Developer/CoreSimulator/Caches"))
        },

        CleanupDefinition(
            id: "gradle-old", name: "Gradle caches (all but newest version)", group: "Developer",
            explanation: "Per-version Gradle caches, build cache and daemon logs. Re-created on the next Android build.",
            risk: .safe
        ) {
            let caches = FileUtils.url(".gradle/caches")
            let versioned = FileUtils.children(of: caches).filter {
                let name = $0.lastPathComponent
                return name.first?.isNumber == true && name.contains(".")
            }
            let newest = versioned.max {
                $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedAscending
            }
            return versioned.filter { $0 != newest }
                + FileUtils.children(of: caches).filter { $0.lastPathComponent.hasPrefix("build-cache") }
                + FileUtils.children(of: FileUtils.url(".gradle/daemon"))
        },

        CleanupDefinition(
            id: "npm", name: "npm / pnpm package caches", group: "Developer",
            explanation: "Downloaded package tarballs. Your projects' node_modules are not touched.",
            risk: .safe
        ) {
            FileUtils.children(of: FileUtils.url(".npm/_cacache"))
                + FileUtils.children(of: FileUtils.url("Library/pnpm/store"))
        },

        CleanupDefinition(
            id: "xcode-archives", name: "Xcode Archives", group: "Developer",
            explanation: "Old release builds. They hold the dSYMs needed to read crash reports of apps you shipped.",
            risk: .review
        ) { FileUtils.children(of: FileUtils.url("Library/Developer/Xcode/Archives")) },

        CleanupDefinition(
            id: "ios-device-support", name: "iOS DeviceSupport", group: "Developer",
            explanation: "Debug symbols per iOS version. Xcode re-copies them (takes minutes) when the device is plugged in.",
            risk: .review
        ) { FileUtils.children(of: FileUtils.url("Library/Developer/Xcode/iOS DeviceSupport")) },

        CleanupDefinition(
            id: "pub-cache", name: "Flutter / Dart pub cache", group: "Developer",
            explanation: "Downloaded Dart packages. Run `flutter pub get` (needs internet) in each project afterwards.",
            risk: .review
        ) { FileUtils.children(of: FileUtils.url(".pub-cache/hosted")) },

        CleanupDefinition(
            id: "trash", name: "Empty the Trash", group: "Trash",
            explanation: "Deletes everything already in the Trash for good. Check it in Finder first. Shows 0 without Full Disk Access.",
            risk: .permanent
        ) { FileUtils.children(of: FileUtils.url(".Trash")) },
    ]
}
