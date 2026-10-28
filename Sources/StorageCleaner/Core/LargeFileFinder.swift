import Foundation

struct LargeFile: Identifiable, Hashable {
    let url: URL
    let size: Int64
    let modified: Date
    var id: URL { url }

    /// Files under ~/Library belong to apps (databases, VM disks, containers).
    /// Removing them by hand usually breaks the app instead of freeing space safely.
    var isAppData: Bool { url.path.hasPrefix(FileUtils.url("Library").path + "/") }
}

enum LargeFileFinder {
    static func find(
        in folder: URL,
        minimumSize: Int64,
        limit: Int = 300,
        progress: @escaping @Sendable (String) -> Void
    ) -> [LargeFile] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .contentModificationDateKey,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var results: [LargeFile] = []
        var scanned = 0
        for case let url as URL in enumerator {
            if Task.isCancelled { return [] }
            scanned += 1
            if scanned % 2000 == 0 { progress("Scanned \(scanned) items…") }
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true, values.isSymbolicLink != true,
                  let size = values.totalFileAllocatedSize, Int64(size) >= minimumSize else { continue }
            results.append(LargeFile(url: url, size: Int64(size), modified: values.contentModificationDate ?? .distantPast))
        }
        return Array(results.sorted { $0.size > $1.size }.prefix(limit))
    }
}
