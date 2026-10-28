import Foundation

@MainActor
final class LargeFilesModel: ObservableObject {
    @Published var folder: URL = FileUtils.home
    @Published var minimumSize: Int64 = 500_000_000
    @Published var files: [LargeFile] = []
    @Published var selected: Set<URL> = []
    @Published var isScanning = false
    @Published var hasScanned = false
    @Published var progress = ""
    @Published var status: String?

    private var scanTask: Task<Void, Never>?

    var selectedSize: Int64 { files.filter { selected.contains($0.url) }.reduce(0) { $0 + $1.size } }

    func chooseFolder() {
        if let url = FileUtils.chooseFolders(multiple: false).first { folder = url }
    }

    func scan() {
        scanTask?.cancel()
        isScanning = true
        status = nil
        selected = []
        progress = "Scanning…"
        let folder = folder
        let minimumSize = minimumSize
        scanTask = Task.detached(priority: .userInitiated) { [self] in
            let files = LargeFileFinder.find(in: folder, minimumSize: minimumSize) { message in
                Task { @MainActor in self.progress = message }
            }
            let cancelled = Task.isCancelled
            await MainActor.run {
                guard !cancelled else { return }
                self.files = files
                self.isScanning = false
                self.hasScanned = true
            }
        }
    }

    func cancel() {
        scanTask?.cancel()
        isScanning = false
    }

    func toggle(_ file: LargeFile) {
        if selected.contains(file.url) { selected.remove(file.url) } else { selected.insert(file.url) }
    }

    func trashSelected() {
        var trashed: Int64 = 0
        var removed = Set<URL>()
        var failures = 0
        for file in files where selected.contains(file.url) {
            do {
                try FileUtils.remove(file.url, permanently: false)
                trashed += file.size
                removed.insert(file.url)
            } catch {
                failures += 1
            }
        }
        files.removeAll { removed.contains($0.url) }
        selected.subtract(removed)
        status = "Moved \(removed.count) file(s), \(FileUtils.format(trashed)), to the Trash."
            + (failures > 0 ? " \(failures) could not be moved." : "")
    }
}
