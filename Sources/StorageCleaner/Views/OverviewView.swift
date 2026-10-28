import SwiftUI

struct OverviewView: View {
    @ObservedObject var cleanup: CleanupModel
    @Binding var section: AppSection?
    @State private var disk = FileUtils.diskSpace()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                diskCard
                HStack(spacing: 16) {
                    shortcut(.cleanup, value: cleanup.isScanning ? "Measuring…" : FileUtils.format(cleanup.safeSize),
                             caption: "Safe to clear now")
                    shortcut(.duplicates, value: "Find copies", caption: "Downloads, Desktop, Documents")
                    shortcut(.largeFiles, value: "Find big files", caption: "Review what takes space")
                }
                tips
            }
            .padding(24)
        }
        .navigationTitle("Overview")
        .onChange(of: cleanup.isScanning) { disk = FileUtils.diskSpace() }
    }

    private var diskCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Macintosh HD").font(.title2.bold())
            if let disk {
                let used = disk.total - disk.available
                ProgressView(value: Double(used), total: Double(disk.total))
                    .tint(Double(used) / Double(disk.total) > 0.9 ? .red : .accentColor)
                Text("\(FileUtils.format(disk.available)) available of \(FileUtils.format(disk.total))")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private func shortcut(_ target: AppSection, value: String, caption: String) -> some View {
        Button { section = target } label: {
            VStack(alignment: .leading, spacing: 6) {
                Label(target.title, systemImage: target.icon).font(.headline)
                Text(value).font(.title3.bold())
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why “System Data” is big — and what this app leaves alone").font(.headline)
            tip("Docker", "Its disk image grows and never shrinks. Use `docker system prune -a` (removes unused images).")
            tip("iOS Simulators", "Old runtimes live in Xcode → Settings → Components. `xcrun simctl delete unavailable` removes orphaned devices.")
            tip("Android emulators", "Use Device Manager → Wipe Data, and remove unused system images in SDK Manager.")
            tip("Time Machine snapshots", "macOS frees these automatically when space runs low. `tmutil listlocalsnapshots /` lists them.")
            tip("Storage numbers", "macOS updates Settings → Storage slowly; give it a few minutes after cleaning.")
        }
        .padding(18)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private func tip(_ title: String, _ text: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.bold())
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
    }
}
