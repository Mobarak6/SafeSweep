import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case overview, cleanup, duplicates, largeFiles

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .cleanup: "Caches & Junk"
        case .duplicates: "Duplicates"
        case .largeFiles: "Large Files"
        }
    }

    var icon: String {
        switch self {
        case .overview: "internaldrive"
        case .cleanup: "sparkles"
        case .duplicates: "doc.on.doc"
        case .largeFiles: "arrow.up.doc"
        }
    }
}

struct ContentView: View {
    @StateObject private var cleanup = CleanupModel()
    @StateObject private var duplicates = DuplicatesModel()
    @StateObject private var largeFiles = LargeFilesModel()
    @State private var section: AppSection? = .overview

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $section) { item in
                Label(item.title, systemImage: item.icon).tag(item)
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            switch section ?? .overview {
            case .overview: OverviewView(cleanup: cleanup, section: $section)
            case .cleanup: CleanupView(model: cleanup)
            case .duplicates: DuplicatesView(model: duplicates)
            case .largeFiles: LargeFilesView(model: largeFiles)
            }
        }
        .task { await cleanup.scan() }
    }
}

struct RiskBadge: View {
    let risk: Risk

    var body: some View {
        Text(risk.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(risk.color.opacity(0.18), in: Capsule())
            .foregroundStyle(risk.color)
    }
}

/// Bottom action bar shared by every screen.
struct ActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) { content }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
        }
    }
}

struct StatusBanner: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.callout)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .padding([.horizontal, .top], 16)
    }
}
