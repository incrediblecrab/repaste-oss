//
//  AppState.swift
//  Repaste
//

import SwiftUI
import SwiftData
import AppKit
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.repaste", category: "AppState")

@Observable
final class AppState {
    static let shared = AppState()

    var editingPaste: Phrase?
    var copiedPasteId: UUID?

    private init() {}

    /// Updates NSApp appearance based on stored appearance mode preference
    static func updateAppearance() {
        guard let app = NSApp else { return }
        let mode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "System"
        switch mode {
        case "Light", "Solid Light":
            app.appearance = NSAppearance(named: .aqua)
        case "Dark", "Solid Dark":
            app.appearance = NSAppearance(named: .darkAqua)
        default:
            app.appearance = nil
        }
    }

    /// Saves model context with error logging
    static func save(_ context: ModelContext, operation: String = "save") {
        do {
            try context.save()
        } catch {
            logger.error("Failed to \(operation): \(error.localizedDescription)")
        }
    }

    func startEditing(_ paste: Phrase) {
        editingPaste = paste
    }

    func startAdding() {
        editingPaste = nil
    }

    func clearEditing() {
        editingPaste = nil
    }

    func showCopied(for pasteId: UUID) {
        // Play selected sound (copy to allow overlapping plays)
        let soundName = UserDefaults.standard.string(forKey: "copySound") ?? "Glass"
        if !soundName.isEmpty, let sound = NSSound(named: .init(soundName))?.copy() as? NSSound {
            sound.play()
        }

        // Update state with animation
        withAnimation(.easeOut(duration: 0.15)) {
            copiedPasteId = pasteId
        }

        // Clear indicator after 1 second display duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            if self?.copiedPasteId == pasteId {
                withAnimation(.easeIn(duration: 0.15)) {
                    self?.copiedPasteId = nil
                }
            }
        }
    }
}
