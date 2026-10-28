import SwiftUI

struct CleanupView: View {
    @ObservedObject var model: CleanupModel
    @State private var confirming = false
    @State private var showErrors = false

    var body: some View {
        VStack(spacing: 0) {
            if let status = model.status { StatusBanner(text: status) }
            List {
                ForEach(CleanupCatalog.groups, id: \.self) { group in
                    Section(group) {
                        ForEach(model.items.indices.filter { model.items[$0].definition.group == group }, id: \.self) { index in
                            CleanupRow(item: $model.items[index])
                        }
                    }
                }
            }
            .overlay {
                if model.isScanning && model.items.isEmpty { ProgressView("Measuring caches…") }
            }
            ActionBar {
                Toggle("Move to Trash (recoverable)", isOn: $model.moveToTrash)
                    .toggleStyle(.checkbox)
                    .help("Turn off to delete immediately. Caches marked Safe are rebuilt automatically either way.")
                if !model.errors.isEmpty {
                    Button("\(model.errors.count) skipped") { showErrors = true }.buttonStyle(.link)
                }
                Spacer()
                if model.isScanning || model.isCleaning { ProgressView().controlSize(.small) }
                Text("Selected: \(FileUtils.format(model.selectedSize))").monospacedDigit()
                Button("Rescan") { Task { await model.scan() } }
                    .disabled(model.isScanning || model.isCleaning)
                Button("Clean Selected") { confirming = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.selectedSize == 0 || model.isScanning || model.isCleaning)
            }
        }
        .navigationTitle("Caches & Junk")
        .confirmationDialog("Clean \(FileUtils.format(model.selectedSize))?", isPresented: $confirming) {
            Button("Clean", role: .destructive) { Task { await model.clean() } }
        } message: {
            Text(confirmationMessage)
        }
        .sheet(isPresented: $showErrors) { ErrorList(errors: model.errors) }
    }

    private var confirmationMessage: String {
        var text = model.moveToTrash
            ? "Items go to the Trash, so you can restore them until you empty it."
            : "Items are deleted immediately."
        if model.hasPermanentSelection { text += " Items already in the Trash are deleted for good." }
        return text
    }
}

private struct CleanupRow: View {
    @Binding var item: CleanupItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: $item.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(item.entries.isEmpty)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.definition.name).font(.headline)
                    RiskBadge(risk: item.definition.risk)
                }
                Text(item.definition.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Text(item.entries.isEmpty ? "—" : FileUtils.format(item.size))
                .font(.headline.monospacedDigit())
                .foregroundStyle(item.entries.isEmpty ? .secondary : .primary)
            Button {
                FileUtils.reveal(item.entries.map(\.url))
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Show in Finder")
            .disabled(item.entries.isEmpty)
        }
        .padding(.vertical, 4)
    }
}

struct ErrorList: View {
    let errors: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skipped items").font(.headline)
            Text("These were open in another app or protected by macOS. Nothing else was affected.")
                .font(.callout).foregroundStyle(.secondary)
            List(errors, id: \.self) { Text($0).font(.caption.monospaced()) }
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(20)
        .frame(width: 620, height: 420)
    }
}
