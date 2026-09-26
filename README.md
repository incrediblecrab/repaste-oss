# repaste-oss

Repaste is a public MIT-licensed macOS menu bar app for saving and pasting text snippets and file references. This repository is the open-source release of the private [incrediblecrab/repaste](https://github.com/incrediblecrab/repaste) app; the private repository's sync note says this repo receives the app sources, assets, models, services, views, and root app files, while internal icon assets stay private.

**Objective:** provide a buildable public Repaste source release with local signing instructions and no private project notes.

**Inputs:** Xcode 26 or later, a Mac running macOS 15.6 or later, an Apple ID for local signing, and an Apple Developer account only if you want CloudKit-backed iCloud sync.

**Files:**

- [`repaste/`](repaste/): app sources, including assets, models, services, views, `ContentView.swift`, and `repasteApp.swift`
- [`repasteTests/`](repasteTests/): unit test target
- [`repasteUITests/`](repasteUITests/): UI test target
- [`repaste.xcodeproj`](repaste.xcodeproj): Xcode project

**Try it:** run `git clone https://github.com/incrediblecrab/repaste-oss.git`, `cd repaste-oss`, `xcodebuild -list -project repaste.xcodeproj`, then open `repaste.xcodeproj`, select the `repaste` scheme and the My Mac destination, set your signing team, and build.

## Features

Repaste saves text snippets and file references, pins frequently used pastes, organizes with colored tags, searches and filters saved items, drags file references, opens a floating window, syncs through iCloud when configured, locks with Touch ID or passcode, imports and exports JSON, tracks usage statistics, and supports system, light, dark, and solid appearance modes.

## Local signing and iCloud

In Xcode, select the `repaste` target, open Signing & Capabilities, enable automatic signing, choose your team, and change the bundle identifier from `com.example.repaste` to a value you control. Repeat for the test targets if you plan to run tests.

For iCloud sync, open `repaste/repaste.entitlements`, change `iCloud.com.example.repaste` to a container matching your bundle ID, and enable CloudKit in your Apple Developer account at [developer.apple.com](https://developer.apple.com). If you do not need iCloud sync, disable it in the app's settings after building.

## How it works

Click the Repaste menu bar icon to open the popover. Use the plus button to create a text snippet or file reference, click a text paste to copy it, drag a file paste where you need it, right-click a paste to pin, move, edit, or delete it, and use the tag filter to narrow the list. The window icon opens a floating window, and the gear icon opens settings.

## Architecture

The app uses `MenuBarExtra` with `.window` style, SwiftData models in `repaste/Models/Phrase.swift`, `@AppStorage` preferences, `@Query` fetching, security-scoped bookmarks for sandboxed file access, and an observable `AppState` singleton for cross-view state and copy feedback.

## Development

Use this command to check for build errors after changes:

```bash
xcodebuild -scheme repaste -sdk macosx build 2>&1 | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" | head -50
```

Build for Mac. Do not run the simulator for routine checks.

## License

MIT. See [`LICENSE`](LICENSE).
