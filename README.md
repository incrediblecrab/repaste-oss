# Repaste

A macOS menu bar app for saving and pasting text snippets and file references. Built with SwiftUI and SwiftData.

## Features

- Save text snippets and file references for quick access
- Pin frequently used pastes to the top
- Organize with colored tags
- Search and filter your pastes
- Drag and drop file references
- Pop-out floating window (always on top)
- iCloud sync across devices
- Biometric lock (Touch ID / passcode)
- JSON export and import
- Usage statistics
- Customizable appearance (system, light, dark, solid modes)

## Requirements

- macOS 15.6 or later
- Xcode 26 or later (free from the Mac App Store)
- An Apple ID (free — needed to run on your Mac)
- An Apple Developer account (only if you want iCloud sync)

## Getting Started

### 1. Download the project

```bash
git clone https://github.com/YOUR_USERNAME/repaste-oss.git
cd repaste-oss
```

Or click **Code > Download ZIP** on GitHub and unzip it.

### 2. Open in Xcode

Double-click `repaste.xcodeproj` to open the project in Xcode.

### 3. Set your signing identity

Before you can build, Xcode needs to know who you are:

1. In Xcode, click `repaste` in the project navigator (left sidebar, top item)
2. Select the `repaste` target (not the project)
3. Go to the **Signing & Capabilities** tab
4. Check **Automatically manage signing**
5. Select your **Team** from the dropdown (your Apple ID)
6. Change the **Bundle Identifier** from `com.example.repaste` to something unique, like `com.yourname.repaste`

Repeat for the `repasteTests` and `repasteUITests` targets if you plan to run tests.

### 4. Update iCloud container (optional)

If you want iCloud sync to work:

1. Open `repaste/repaste.entitlements` in Xcode
2. Under **iCloud Container Identifiers**, change `iCloud.com.example.repaste` to `iCloud.com.yourname.repaste` (matching your bundle ID)
3. Enable CloudKit in your Apple Developer account at [developer.apple.com](https://developer.apple.com)

If you don't need iCloud sync, you can disable it in the app's settings after building.

### 5. Build and run

Press `Cmd + R` or click the play button. The app will appear as an icon in your menu bar.

> **Troubleshooting:** If the build fails with a signing error, make sure your Team is selected in step 3. A free Apple ID works for local development — you just can't distribute to the App Store without a paid developer account.

## How the App Works

**Menu bar icon** — Click the Repaste icon in your menu bar to open the popover.

**Adding pastes** — Click `+` to create a new text snippet or file reference. Give it a name, type your content, and save.

**Using pastes** — Click any text paste to copy it to your clipboard. For file pastes, drag them to where you need them.

**Organizing** — Right-click a paste to pin it, move it up/down, edit, or delete. Use tags to categorize and the filter menu to show specific tags.

**Pop-out window** — Click the window icon in the toolbar to open a floating window that stays on top of other apps.

**Settings** — Click the gear icon to change theme, sounds, window height, and manage your data.

## Architecture

```
repaste/
├── repasteApp.swift              # App entry point, MenuBarExtra scene
├── ContentView.swift             # Main menu bar window + floating window
├── Models/
│   └── Phrase.swift              # SwiftData models (Phrase, Tag, UsageEvent)
├── Services/
│   ├── AppState.swift            # Observable singleton for shared state
│   └── ClipboardService.swift    # NSPasteboard wrapper
└── Views/
    ├── PasteRowView.swift        # Individual paste row with actions
    ├── PasteEditSheet.swift      # Add/edit paste form
    ├── SettingsView.swift        # Settings with appearance, data, security
    ├── StatsView.swift           # Usage statistics
    └── TagManagerView.swift      # Tag CRUD with color palette
```

### Key Patterns

- `MenuBarExtra` with `.window` style for the menu bar popover
- `@AppStorage` for user preferences (stored in UserDefaults)
- `@Query` for SwiftData fetching with `modelContext.save()` after mutations
- Security-scoped bookmarks for sandboxed file access
- `@Observable` singleton (`AppState`) for cross-view state and copy feedback
- Pinned pastes sorted by `pinnedAt` date, unpinned by `order` field

## Using with AI Coding Tools

This project works well with AI coding assistants like Claude Code, Codex, and Gemini. Here's how to get them up to speed quickly.

### Build command

Use this to check for errors after making changes:

```bash
xcodebuild -scheme repaste -sdk macosx build 2>&1 | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" | head -50
```

### Context to give the AI

When starting a session, point the tool at the project root and share this context:

> Repaste is a macOS menu bar app (SwiftUI + SwiftData). It runs as a `MenuBarExtra` window. The entry point is `repasteApp.swift`. Data models are in `Models/Phrase.swift` (Phrase, Tag, UsageEvent). Shared state lives in `Services/AppState.swift`. The main UI is `ContentView.swift` with individual views in `Views/`. Use native SwiftUI controls only — no hardcoded colors, fonts, or spacing. Use SF Symbols for icons. Build with: `xcodebuild -scheme repaste -sdk macosx build`.

### File reference

| File | What it does |
|------|-------------|
| `repasteApp.swift` | App entry, window registration, biometric lock |
| `ContentView.swift` | Menu bar popover UI, floating window, toolbar |
| `Models/Phrase.swift` | `Phrase`, `Tag`, `UsageEvent` SwiftData models, `Color` hex extensions |
| `Services/AppState.swift` | Observable singleton: editing state, copy feedback, appearance, save helper |
| `Services/ClipboardService.swift` | `NSPasteboard` wrapper for text and file copying |
| `Views/PasteRowView.swift` | Row display, tap-to-copy, drag-to-use, context menu, file bookmark resolution |
| `Views/PasteEditSheet.swift` | Add/edit form with tag picker, file browser, flow layout |
| `Views/SettingsView.swift` | Settings form, appearance modes, export/import, `AppearanceMode` enum |
| `Views/StatsView.swift` | Usage statistics display and export |
| `Views/TagManagerView.swift` | Tag CRUD with 12-color palette |

### Guidelines for AI tools

- **Read before editing** — understand existing patterns before changing anything
- **Use native SwiftUI** — semantic colors (`.primary`, `.secondary`), SF Symbols, no hardcoded values
- **Save after mutations** — always call `AppState.save(modelContext, operation: "description")`
- **Respect the sandbox** — file access requires security-scoped bookmarks
- **Don't run the simulator** — use the `xcodebuild` command above to verify builds
- **Don't open the Xcode project** — edit files directly, verify with the build command

## License

MIT License. See [LICENSE](LICENSE) for details.
