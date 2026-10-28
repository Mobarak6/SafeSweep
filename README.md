# Storage Cleaner

A native macOS app that frees disk space **without risking your data**. It clears caches that rebuild themselves, finds byte-for-byte duplicate files, and surfaces the largest files on your disk, and by default everything it removes goes to the Trash so it can be restored.

Built with SwiftUI. No dependencies, no network access, no telemetry.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)

---

## Features

| Screen | What it does |
|---|---|
| **Overview** | Disk usage, how much can be reclaimed safely, and guidance on what inflates macOS "System Data" |
| **Caches & Junk** | Measures 10 cache categories, each labelled **Safe**, **Review** or **Permanent**, and cleans the ones you select |
| **Duplicates** | Finds identical files in the folders you choose and keeps one copy of each |
| **Large Files** | Lists the biggest files in any folder so you can decide what to remove |

### What "Caches & Junk" covers

| Category | Location | Risk |
|---|---|---|
| App & browser caches | `~/Library/Caches` | Safe |
| App logs & crash reports | `~/Library/Logs` | Safe |
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` | Safe |
| SwiftUI preview & simulator caches | `~/Library/Developer/Xcode/UserData/Previews`, `CoreSimulator/Caches` | Safe |
| Gradle caches (all but the newest version) | `~/.gradle/caches`, `~/.gradle/daemon` | Safe |
| npm / pnpm package caches | `~/.npm/_cacache`, `~/Library/pnpm/store` | Safe |
| Xcode Archives | `~/Library/Developer/Xcode/Archives` | Review |
| iOS DeviceSupport | `~/Library/Developer/Xcode/iOS DeviceSupport` | Review |
| Flutter / Dart pub cache | `~/.pub-cache/hosted` | Review |
| Trash | `~/.Trash` | Permanent |

- **Safe**: rebuilt automatically by the owning app or tool. Pre-selected.
- **Review**: rebuildable, but costs a re-download or holds something worth checking first (for example, dSYMs in Archives). Never pre-selected.
- **Permanent**: emptying the Trash cannot be undone. Never pre-selected.

## Safety model

Storage Cleaner is designed so that a mis-click cannot cost you data:

1. **Trash by default.** Removed items are moved to the Trash. You can opt out for caches only; duplicates and large files always go to the Trash.
2. **Conservative defaults.** Only categories marked *Safe* are pre-selected. Large Files pre-selects nothing.
3. **One copy is always kept.** In every duplicate set the oldest file is kept by default, and the UI will not let you select every copy. Before trashing, the app re-checks that a kept copy still exists on disk.
4. **True duplicates only.** Files are matched by size, then a SHA-256 of the first 64 KB, then a full SHA-256. Hard links are recognised and never reported as duplicates.
5. **Hands off app internals.** Duplicate scans skip app bundles, Photos libraries, hidden files, `~/Library`, and tool folders such as `node_modules`, `.git`, `build`, `Pods` and `.dart_tool`. Large files under `~/Library` are flagged as *App data — leave alone*.
6. **Confirmation before every removal**, with a list of anything macOS refused to move.

## Requirements

- macOS 14 Sonoma or later
- Xcode 15+ or the Swift 5.9+ command-line toolchain (`xcode-select --install`)

## Getting started

```bash
git clone <repository-url>
cd StorageCleaner
make run
```

`make run` builds a release binary, wraps it in `Storage Cleaner.app`, ad-hoc signs it, installs it into `~/Applications` and launches it.

### Make targets

| Command | Description |
|---|---|
| `make build` | Debug build |
| `make test` | Run unit tests |
| `make install` | Build `Storage Cleaner.app` and copy it to `~/Applications` (same as `./build.sh`) |
| `make run` | Install and launch |
| `make clean` | Delete `.build/` and `build/` |

To work in Xcode, open `Package.swift` and run the `StorageCleaner` scheme.

## Permissions

The app is not sandboxed, because it needs to read caches across your home folder.

- The first time you scan **Desktop**, **Documents** or **Downloads**, macOS asks for access. Allow it.
- To measure and empty the **Trash**, grant **Full Disk Access**: *System Settings → Privacy & Security → Full Disk Access → +* and add `Storage Cleaner.app`. Without it the Trash row shows 0.
- Some caches belong to running apps or are protected by macOS. These are skipped and listed after a clean; nothing else is affected.

## Project structure

```
StorageCleaner/
├── Package.swift                  # SwiftPM manifest (macOS 14+)
├── Info.plist                     # App bundle metadata
├── build.sh                       # Builds, signs and installs the .app
├── Makefile                       # Convenience targets
├── Sources/StorageCleaner/
│   ├── StorageCleanerApp.swift    # App entry point
│   ├── Core/
│   │   ├── CleanupCatalog.swift   # Cache categories, locations and risk levels
│   │   ├── DuplicateFinder.swift  # Size → partial hash → full SHA-256 matching
│   │   ├── LargeFileFinder.swift  # Largest-file scan
│   │   └── FileUtils.swift        # Sizing, Trash/remove, Finder helpers
│   ├── Models/                    # @MainActor view models (one per screen)
│   └── Views/                     # SwiftUI screens
└── Tests/StorageCleanerTests/     # Duplicate-detection tests
```

### Adding a cache category

Append a `CleanupDefinition` to `CleanupCatalog.all`:

```swift
CleanupDefinition(
    id: "yarn", name: "Yarn cache", group: "Developer",
    explanation: "Downloaded packages. Re-fetched on the next install.",
    risk: .safe
) { FileUtils.children(of: FileUtils.url("Library/Caches/Yarn")) }
```

The closure returns the **children** to remove, never the parent folder, so the owning tool keeps its directory layout.

## What this app deliberately does not touch

These often dominate "System Data", but they are better managed by their owners:

| Item | Recommended cleanup |
|---|---|
| Docker disk image | `docker system prune -a` |
| iOS Simulator runtimes | Xcode → Settings → Components; `xcrun simctl delete unavailable` |
| Android emulators & system images | Android Studio → Device Manager / SDK Manager |
| Time Machine local snapshots | Freed automatically by macOS; inspect with `tmutil listlocalsnapshots /` |

## Troubleshooting

- **Space didn't change after cleaning:** items moved to the Trash still use space until you empty it. *Settings → Storage* can also take a few minutes to refresh.
- **"Storage Cleaner can't be opened":** the app is ad-hoc signed. Right-click it in Finder and choose **Open** the first time.
- **Scan feels slow:** large Gradle or Docker folders take a while to measure. Rescans are faster once the file system metadata is cached.
