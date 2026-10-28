import SwiftUI

struct LargeFilesView: View {
    @ObservedObject var model: LargeFilesModel
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            if let status = model.status { StatusBanner(text: status) }
            results
            ActionBar {
                Text("Nothing is pre-selected. Review each file yourself.").foregroundStyle(.secondary)
                Spacer()
                Text("Selected: \(model.selected.count) · \(FileUtils.format(model.selectedSize))").monospacedDigit()
                Button("Move Selected to Trash") { confirming = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.selected.isEmpty || model.isScanning)
            }
        }
        .navigationTitle("Large Files")
        .confirmationDialog("Move \(model.selected.count) file(s) to the Trash?", isPresented: $confirming) {
            Button("Move to Trash", role: .destructive) { model.trashSelected() }
        } message: {
            Text("You can restore them from the Trash until you empty it.")
        }
    }

    private var controls: some View {
        HStack {
            Text("Folder:").foregroundStyle(.secondary)
            Label(FileUtils.displayPath(model.folder), systemImage: "folder.fill")
            Button("Change…") { model.chooseFolder() }
            Picker("Larger than", selection: $model.minimumSize) {
                ForEach(sizeThresholds.filter { $0.bytes >= 10_000_000 }, id: \.bytes) { Text($0.label).tag($0.bytes) }
            }
            .frame(width: 200)
            Spacer()
            if model.isScanning {
                Button("Cancel") { model.cancel() }
            } else {
                Button("Scan") { model.scan() }.buttonStyle(.borderedProminent)
            }
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
        } else if model.files.isEmpty {
            ContentUnavailableView(
                model.hasScanned ? "No large files found" : "Find what takes the most space",
                systemImage: "arrow.up.doc",
                description: Text("Old installers (.dmg, .zip), videos and exported builds are the usual suspects.")
            )
        } else {
            List(model.files) { file in
                HStack(spacing: 10) {
                    Toggle("", isOn: Binding(get: { model.selected.contains(file.url) }, set: { _ in model.toggle(file) }))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                    Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                        .resizable().frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(file.url.lastPathComponent).lineLimit(1)
                            if file.isAppData {
                                Text("App data — leave alone")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.18), in: Capsule())
                                    .foregroundStyle(.orange)
                                    .help("Belongs to an app (e.g. Docker's disk image or a database). Clean it from inside that app instead.")
                            }
                        }
                        Text(FileUtils.displayPath(file.url.deletingLastPathComponent()))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    Text(file.modified, format: .dateTime.year().month().day())
                        .font(.caption).foregroundStyle(.secondary)
                    Text(FileUtils.format(file.size)).font(.headline.monospacedDigit()).frame(width: 90, alignment: .trailing)
                    Button { FileUtils.reveal([file.url]) } label: { Image(systemName: "magnifyingglass") }
                        .buttonStyle(.borderless)
                        .help("Show in Finder")
                }
            }
        }
    }
}
