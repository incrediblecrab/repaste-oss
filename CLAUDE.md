# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) and GitHub Copilot CLI when working in this repository.

Repaste is a macOS menu bar app (macOS 15.6+) for saving text snippets and file references and pasting them back. This repository is its public, MIT-licensed source release; development happens in a private repository and sources are copied in here. Everything committed here is public, so never add private notes, internal icon assets, real bundle identifiers, team IDs or CloudKit container names.

## Commands

```bash
xcodebuild -scheme repaste -sdk macosx build 2>&1 | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" | head -50
```

Build for Mac only; there is nothing to run in a simulator. Local signing needs your own team and a bundle identifier in place of the placeholder `com.example.repaste`, and iCloud sync needs `repaste/repaste.entitlements` changed from `iCloud.com.example.repaste`; keep those placeholders in commits.

## Structure

All sources are under `repaste/`. `repasteApp.swift` declares a `MenuBarExtra` with `.window` style; `ContentView.swift` is the popover. The one SwiftData model is `Models/Phrase.swift`, fetched with `@Query`. `Services/AppState.swift` is an observable singleton for cross-view state and copy feedback, and `Services/ClipboardService.swift` writes text and file references to the pasteboard. File pastes are stored as security-scoped bookmarks because the app is sandboxed. Sheets and rows are in `Views/` (edit sheet, row, settings, stats, tag manager). Preferences use `@AppStorage`.

Changes to app code belong in the private repository first, then are copied here with the same `repaste/` layout, so a fix made only here is overwritten by the next sync.
