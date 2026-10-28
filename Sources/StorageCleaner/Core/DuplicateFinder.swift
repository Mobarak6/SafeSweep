import CryptoKit
import Foundation

struct DuplicateFile: Identifiable, Hashable {
    let url: URL
    let created: Date
    var id: URL { url }
}

struct DuplicateGroup: Identifiable {
    let id = UUID()
    let size: Int64
    /// Oldest first; the first file is the one kept by default.
    var files: [DuplicateFile]

    var wasted: Int64 { size * Int64(max(files.count - 1, 0)) }
}

enum DuplicateFinder {
    /// Folders whose contents belong to a tool and must not be deduplicated by hand.
    static let skippedFolderNames: Set<String> = [
        "node_modules", ".git", ".svn", "Pods", "build", ".build", ".dart_tool", ".gradle",
        "DerivedData", "vendor", ".venv", "venv", "__pycache__", ".idea", "Library",
    ]

    private static let partialHashBytes = 64 * 1024

    /// Finds byte-for-byte identical files. Files are matched by size, then a hash of the
    /// first 64 KB, then a full SHA-256, so large unique files are never read in full.
    static func find(
        in folders: [URL],
        minimumSize: Int64,
        progress: @escaping @Sendable (String) -> Void
    ) -> [DuplicateGroup] {
        var bySize: [Int64: [URL]] = [:]
        var seenInodes = Set<String>()
        var scanned = 0
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]

        for folder in folders {
            guard let enumerator = FileManager.default.enumerator(
                at: folder,
                includingPropertiesForKeys: Array(keys),
                // Package descendants: never reach inside .app bundles or Photos libraries.
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let url as URL in enumerator {
                if Task.isCancelled { return [] }
                guard let values = try? url.resourceValues(forKeys: keys) else { continue }
                if values.isDirectory == true {
                    if skippedFolderNames.contains(url.lastPathComponent) { enumerator.skipDescendants() }
                    continue
                }
                guard values.isRegularFile == true, values.isSymbolicLink != true,
                      let size = values.fileSize, Int64(size) >= minimumSize else { continue }

                // Hard links and overlapping scan folders point at the same data: count once.
                var info = stat()
                if lstat(url.path, &info) == 0 {
                    guard seenInodes.insert("\(info.st_dev):\(info.st_ino)").inserted else { continue }
                }

                bySize[Int64(size), default: []].append(url)
                scanned += 1
                if scanned % 500 == 0 { progress("Scanned \(scanned) files…") }
            }
        }

        let candidates = bySize.filter { $0.value.count > 1 }
        var groups: [DuplicateGroup] = []
        var compared = 0

        for (size, urls) in candidates {
            if Task.isCancelled { return [] }
            compared += 1
            if compared % 50 == 0 { progress("Comparing contents… \(compared) / \(candidates.count)") }

            let byPartial = Dictionary(grouping: urls) { hash($0, limit: partialHashBytes) ?? UUID().uuidString }
            for sameStart in byPartial.values where sameStart.count > 1 {
                let byFull = size <= Int64(partialHashBytes)
                    ? [String: [URL]](uniqueKeysWithValues: [("all", sameStart)])
                    : Dictionary(grouping: sameStart) { hash($0, limit: nil) ?? UUID().uuidString }
                for identical in byFull.values where identical.count > 1 {
                    let files = identical
                        .map { DuplicateFile(url: $0, created: FileUtils.creationDate(of: $0)) }
                        .sorted { $0.created < $1.created }
                    groups.append(DuplicateGroup(size: size, files: files))
                }
            }
        }
        return groups.sorted { $0.wasted > $1.wasted }
    }

    /// SHA-256 of the whole file, or of only its first `limit` bytes.
    static func hash(_ url: URL, limit: Int?) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        var remaining = limit ?? .max
        while remaining > 0 {
            let read: Bool = autoreleasepool {
                guard let data = try? handle.read(upToCount: min(1 << 20, remaining)), !data.isEmpty else {
                    return false
                }
                hasher.update(data: data)
                remaining -= data.count
                return true
            }
            if !read { break }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
