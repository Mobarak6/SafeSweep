import SwiftUI

let sizeThresholds: [(label: String, bytes: Int64)] = [
    ("100 KB", 100_000), ("1 MB", 1_000_000), ("10 MB", 10_000_000),
    ("100 MB", 100_000_000), ("500 MB", 500_000_000), ("1 GB", 1_000_000_000),
]

struct DuplicatesView: View {
    @ObservedObject var model: DuplicatesModel
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            if let status = model.status { StatusBanner(text: status) }
            results
            ActionBar {
                Text("\(model.groups.count) sets · \(FileUtils.format(model.totalWasted)) in extra copies")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Selected: \(model.selected.count) · \(FileUtils.format(model.selectedSize))").monospacedDigit()
                Button("Move Selected to Trash") { confirming = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.selected.isEmpty || model.isScanning)
            }
        }
        .navigationTitle("Duplicates")
        .confirmationDialog("Move \(model.selected.count) duplicate(s) to the Trash?", isPresented: $confirming) {
            Button("Move to Trash", role: .destructive) { model.trashSelected() }
        } message: {
            Text("At least one copy of every file is kept. You can restore anything from the Trash.")
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Scan in:").foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(model.folders, id: \.self) { folder in
                            HStack(spacing: 4) {
                                Image(systemName: "folder.fill").foregroundStyle(.blue)
                                Text(FileUtils.displayPath(folder))
                                Button { model.folders.removeAll { $0 == folder } } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                        }
                    }
                }
                Button("Add Folder…") { model.addFolders() }
            }
            HStack {
                Picker("Ignore files smaller than", selection: $model.minimumSize) {
                    ForEach(sizeThresholds, id: \.bytes) { Text($0.label).tag($0.bytes) }
                }
                .frame(width: 280)
                Spacer()
                if model.isScanning {
                    Button("Cancel") { model.cancel() }
                } else {
                    Button("Scan for Duplicates") { model.scan() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.folders.isEmpty)
                }
            }
            Text("Skips app bundles, Photos libraries, hidden files, ~/Library and project folders like node_modules, .git and build.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
    }

    @ViewBuilder
    private var results: some View {
        if model.isScanning {
            VStack(spacing: 10) {
                ProgressView()
                Text(model.progress).foregroundStyle(.secondary).monospacedDigit()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.groups.isEmpty {
            ContentUnavailableView(
                model.hasScanned ? "No duplicates found" : "Find identical files",
                systemImage: "doc.on.doc",
                description: Text(model.hasScanned
                    ? "Every file in these folders is unique."
                    : "Files are compared byte by byte, so only true copies are listed.")
            )
        } else {
            List {
                ForEach(model.groups) { group in
                    Section {
                        ForEach(group.files) { file in
                            DuplicateRow(model: model, group: group, file: file)
                        }
                    } header: {
                        Text("\(group.files.count) copies · \(FileUtils.format(group.size)) each · \(FileUtils.format(group.wasted)) extra")
                    }
                }
            }
        }
    }
}

private struct DuplicateRow: View {
    @ObservedObject var model: DuplicatesModel
    let group: DuplicateGroup
    let file: DuplicateFile

    var body: some View {
        let isSelected = model.selected.contains(file.url)
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { isSelected }, set: { _ in model.toggle(file, in: group) }))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(!model.canSelect(file, in: group))
                .help(model.canSelect(file, in: group) ? "" : "At least one copy is always kept")
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                .resizable().frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.url.lastPathComponent).lineLimit(1)
                Text(FileUtils.displayPath(file.url.deletingLastPathComponent()))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if !isSelected {
                Text("Keep").font(.caption.bold()).foregroundStyle(.green)
            }
            Text(file.created, format: .dateTime.year().month().day())
                .font(.caption).foregroundStyle(.secondary)
            Menu {
                Button("Show in Finder") { FileUtils.reveal([file.url]) }
                Button("Keep only this copy") { model.keepOnly(file, in: group) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}
