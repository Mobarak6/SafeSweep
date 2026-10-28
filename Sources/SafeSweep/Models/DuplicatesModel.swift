import Foundation

@MainActor
final class DuplicatesModel: ObservableObject {
    @Published var folders: [URL] = ["Downloads", "Desktop", "Documents"]
        .map(FileUtils.url)
        .filter { FileManager.default.fileExists(atPath: $0.path) }
    @Published var minimumSize: Int64 = 1_000_000
    @Published var groups: [DuplicateGroup] = []
    @Published var selected: Set<URL> = []
    @Published var isScanning = false
    @Published var hasScanned = false
    @Published var progress = ""
    @Published var status: String?

    private var scanTask: Task<Void, Never>?

    var totalWasted: Int64 { groups.reduce(0) { $0 + $1.wasted } }
    var selectedSize: Int64 {
        groups.reduce(0) { total, group in
            total + group.size * Int64(group.files.filter { selected.contains($0.url) }.count)
        }
    }

    func addFolders() {
        for url in FileUtils.chooseFolders(multiple: true) where !folders.contains(url) {
            folders.append(url)
        }
    }

    func scan() {
        scanTask?.cancel()
        isScanning = true
        status = nil
        progress = "Listing files…"
        let folders = folders
        let minimumSize = minimumSize
        scanTask = Task.detached(priority: .userInitiated) { [self] in
            let groups = DuplicateFinder.find(in: folders, minimumSize: minimumSize) { message in
                Task { @MainActor in self.progress = message }
            }
            let cancelled = Task.isCancelled
            await MainActor.run {
                guard !cancelled else { return }
                self.groups = groups
                // Keep the oldest copy, pre-select the rest.
                self.selected = Set(groups.flatMap { $0.files.dropFirst().map(\.url) })
                self.isScanning = false
                self.hasScanned = true
            }
        }
    }

    func cancel() {
        scanTask?.cancel()
        isScanning = false
    }

    /// A file can only be selected while at least one other copy in its group stays unselected.
    func canSelect(_ file: DuplicateFile, in group: DuplicateGroup) -> Bool {
        if selected.contains(file.url) { return true }
        return group.files.filter { !selected.contains($0.url) }.count > 1
    }

    func toggle(_ file: DuplicateFile, in group: DuplicateGroup) {
        if selected.contains(file.url) {
            selected.remove(file.url)
        } else if canSelect(file, in: group) {
            selected.insert(file.url)
        }
    }

    func keepOnly(_ file: DuplicateFile, in group: DuplicateGroup) {
        for other in group.files { selected.insert(other.url) }
        selected.remove(file.url)
    }

    func trashSelected() {
        var trashed: Int64 = 0
        var failures = 0
        var removed = Set<URL>()

        for group in groups {
            let keepers = group.files.filter { !selected.contains($0.url) }
            // Safety net: never trash a group's copies unless a kept copy still exists on disk.
            guard keepers.contains(where: { FileManager.default.fileExists(atPath: $0.url.path) }) else { continue }
            for file in group.files where selected.contains(file.url) {
                do {
                    try FileUtils.remove(file.url, permanently: false)
                    trashed += group.size
                    removed.insert(file.url)
                } catch {
                    failures += 1
                }
            }
        }

        groups = groups
            .map { DuplicateGroup(size: $0.size, files: $0.files.filter { !removed.contains($0.url) }) }
            .filter { $0.files.count > 1 }
        selected.subtract(removed)
        status = "Moved \(removed.count) duplicate(s), \(FileUtils.format(trashed)), to the Trash."
            + (failures > 0 ? " \(failures) could not be moved." : "")
    }
}
