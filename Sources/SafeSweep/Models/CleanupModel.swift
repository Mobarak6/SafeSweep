import Foundation

struct CleanupEntry {
    let url: URL
    let size: Int64
}

struct CleanupItem: Identifiable {
    let definition: CleanupDefinition
    let entries: [CleanupEntry]
    var isSelected: Bool

    var id: String { definition.id }
    var size: Int64 { entries.reduce(0) { $0 + $1.size } }
}

@MainActor
final class CleanupModel: ObservableObject {
    @Published var items: [CleanupItem] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var moveToTrash = true
    @Published var status: String?
    @Published var errors: [String] = []

    var selectedSize: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.size } }
    var safeSize: Int64 { items.filter { $0.definition.risk == .safe }.reduce(0) { $0 + $1.size } }
    var hasPermanentSelection: Bool { items.contains { $0.isSelected && $0.definition.risk == .permanent } }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        items = await withTaskGroup(of: (Int, CleanupItem).self) { group in
            for (index, definition) in CleanupCatalog.all.enumerated() {
                group.addTask { (index, Self.measure(definition)) }
            }
            var results: [(Int, CleanupItem)] = []
            for await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    nonisolated private static func measure(_ definition: CleanupDefinition) -> CleanupItem {
        let entries = definition.items()
            .map { CleanupEntry(url: $0, size: FileUtils.allocatedSize(of: $0)) }
            .filter { $0.size > 0 }
        // Only categories that rebuild themselves are pre-selected.
        return CleanupItem(definition: definition, entries: entries, isSelected: definition.risk == .safe && !entries.isEmpty)
    }

    func clean() async {
        let targets = items.filter(\.isSelected)
        guard !targets.isEmpty else { return }
        isCleaning = true
        status = nil
        errors = []
        let toTrash = moveToTrash

        let (removed, trashed, failures) = await Task.detached(priority: .userInitiated) {
            var removed: Int64 = 0
            var trashed: Int64 = 0
            var failures: [String] = []
            for item in targets {
                let permanently = item.definition.risk == .permanent || !toTrash
                for entry in item.entries {
                    do {
                        try FileUtils.remove(entry.url, permanently: permanently)
                        if permanently { removed += entry.size } else { trashed += entry.size }
                    } catch {
                        failures.append("\(FileUtils.displayPath(entry.url)) — \(error.localizedDescription)")
                    }
                }
            }
            return (removed, trashed, failures)
        }.value

        var parts: [String] = []
        if removed > 0 { parts.append("Freed \(FileUtils.format(removed)).") }
        if trashed > 0 { parts.append("Moved \(FileUtils.format(trashed)) to the Trash — empty it to get the space back.") }
        if !failures.isEmpty { parts.append("\(failures.count) item(s) were in use or protected and were skipped.") }
        status = parts.isEmpty ? "Nothing was removed." : parts.joined(separator: " ")
        errors = failures
        isCleaning = false
        await scan()
    }
}
