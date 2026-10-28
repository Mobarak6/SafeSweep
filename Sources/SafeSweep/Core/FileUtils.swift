import AppKit
import Foundation

enum FileUtils {
    static let fm = FileManager.default
    static let home = fm.homeDirectoryForCurrentUser

    static func url(_ relativeToHome: String) -> URL {
        home.appendingPathComponent(relativeToHome)
    }

    /// Direct children of a folder, including hidden ones. Empty if missing or unreadable.
    static func children(of url: URL) -> [URL] {
        (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])) ?? []
    }

    private static let sizeKeys: Set<URLResourceKey> = [
        .isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    /// Bytes actually used on disk by a file or a whole folder. Symlinks are never followed.
    static func allocatedSize(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: sizeKeys),
              values.isSymbolicLink != true else { return 0 }
        if values.isDirectory != true { return fileSize(values) }

        var total: Int64 = 0
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(sizeKeys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }
        for case let file as URL in enumerator {
            if let values = try? file.resourceValues(forKeys: sizeKeys) {
                total += fileSize(values)
            }
        }
        return total
    }

    private static func fileSize(_ values: URLResourceValues) -> Int64 {
        guard values.isRegularFile == true else { return 0 }
        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }

    static func diskSpace() -> (total: Int64, available: Int64)? {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return (Int64(total), available)
    }

    /// Moves to the Trash (recoverable) unless `permanently` is set.
    static func remove(_ url: URL, permanently: Bool) throws {
        if permanently {
            try fm.removeItem(at: url)
        } else {
            try fm.trashItem(at: url, resultingItemURL: nil)
        }
    }

    static func creationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }

    static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func displayPath(_ url: URL) -> String {
        let path = url.path
        return path.hasPrefix(home.path) ? "~" + path.dropFirst(home.path.count) : path
    }

    static func reveal(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(Array(urls.prefix(50)))
    }

    @MainActor
    static func chooseFolders(multiple: Bool) -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = multiple
        panel.prompt = "Choose"
        return panel.runModal() == .OK ? panel.urls : []
    }
}
