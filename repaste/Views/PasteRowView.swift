//
//  PasteRowView.swift
//  Repaste
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.repaste", category: "PasteRow")

struct PasteRowView: View {
    let paste: Phrase
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("previewLineCount") private var previewLineCount = 1

    @State private var fileAvailable: Bool?

    private var showCopied: Bool {
        AppState.shared.copiedPasteId == paste.id
    }

    private var isFileAvailable: Bool {
        if paste.type == .text { return true }
        return fileAvailable ?? true
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(paste.title)
                    .font(.headline)
                    .lineLimit(1)

                if previewLineCount > 0 {
                    Text(previewText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(previewLineCount)
                }
            }

            Spacer()

            if paste.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
            }

            if paste.type == .file {
                if isFileAvailable {
                    Image(systemName: "doc")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("File unavailable")
                        .help("File unavailable on this device")
                }
            }
        }
        .opacity(showCopied ? 0.3 : 1)
        .animation(nil, value: showCopied)
        .padding(.horizontal, 10)
        .padding(.vertical)
        .contentShape(Rectangle())
        .overlay(alignment: .center) {
            if showCopied {
                Label("Copied", systemImage: "doc.on.doc")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(nsColor: .textBackgroundColor))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .textColor), in: RoundedRectangle(cornerRadius: 999))
                    .compositingGroup()
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(paste.title), \(paste.type == .text ? "text" : "file") phrase\(paste.isPinned ? ", pinned" : "")")
        .accessibilityHint(paste.type == .text ? "Tap to copy" : "Drag to use file")
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            if paste.type == .text {
                copyPaste()
                AppState.shared.showCopied(for: paste.id)
            }
            // Files are drag-only, no click-to-copy
        }
        .onDrag { draggableItem }
        .onAppear { checkFileAvailability() }
        .onChange(of: paste.fileBookmark) { checkFileAvailability() }
        .contextMenu {
            if paste.type == .file && !isFileAvailable {
                Button {
                    relinkFile()
                } label: {
                    Label("Re-link File", systemImage: "arrow.triangle.2.circlepath")
                }

                Text("File unavailable on this device")
                    .foregroundStyle(.secondary)

                Divider()
            } else {
                Button {
                    copyPaste()
                    AppState.shared.showCopied(for: paste.id)
                    onCopy()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }

            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                paste.isPinned.toggle()
                paste.pinnedAt = paste.isPinned ? Date() : nil
                AppState.save(modelContext, operation: "toggle pin")
            } label: {
                Label(paste.isPinned ? "Unpin" : "Pin", systemImage: paste.isPinned ? "pin.slash" : "pin")
            }

            Divider()

            Button {
                onMoveUp()
            } label: {
                Label("Move Up", systemImage: "arrow.up")
            }

            Button {
                onMoveDown()
            } label: {
                Label("Move Down", systemImage: "arrow.down")
            }

            Divider()

            Button(role: .destructive) {
                modelContext.delete(paste)
                AppState.save(modelContext, operation: "delete paste")
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Preview Text

    private var previewText: String {
        paste.content
    }

    // MARK: - Drag Content

    private var draggableItem: NSItemProvider {
        if paste.type == .file {
            guard let bookmark = paste.fileBookmark else {
                logger.warning("No bookmark data for file paste: \(paste.title)")
                return NSItemProvider(object: paste.content as NSString)
            }

            guard let url = resolveBookmark(bookmark) else {
                logger.warning("Failed to resolve bookmark for: \(paste.title)")
                return NSItemProvider(object: paste.content as NSString)
            }

            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Use unique temp filename to prevent collisions
            let tempDir = FileManager.default.temporaryDirectory
            let uniqueName = "\(paste.id.uuidString)_\(url.lastPathComponent)"
            let tempURL = tempDir.appendingPathComponent(uniqueName)

            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)

                // Rename temp file back to original name for clean drag
                let cleanTempURL = tempDir.appendingPathComponent(url.lastPathComponent)
                if FileManager.default.fileExists(atPath: cleanTempURL.path) {
                    try FileManager.default.removeItem(at: cleanTempURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: cleanTempURL)

                let provider = NSItemProvider(contentsOf: cleanTempURL) ?? NSItemProvider()

                // Register plain text (file path) for text fields and terminals
                provider.registerDataRepresentation(
                    forTypeIdentifier: UTType.utf8PlainText.identifier,
                    visibility: .all
                ) { completion in
                    completion(url.path.data(using: .utf8), nil)
                    return nil
                }

                provider.suggestedName = url.lastPathComponent
                return provider
            } catch {
                logger.error("Failed to copy file for drag: \(error.localizedDescription)")
                return NSItemProvider(object: url.path as NSString)
            }
        }
        return NSItemProvider(object: paste.content as NSString)
    }

    // MARK: - Actions

    private func copyPaste() {
        switch paste.type {
        case .text:
            ClipboardService.shared.copyText(paste.content)
        case .file:
            if let bookmark = paste.fileBookmark,
               let url = resolveBookmark(bookmark) {
                _ = url.startAccessingSecurityScopedResource()
                ClipboardService.shared.copyFile(at: url)
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Record usage event
        let event = UsageEvent(title: paste.title, type: paste.type)
        modelContext.insert(event)
    }

    private func checkFileAvailability() {
        guard paste.type == .file, let bookmark = paste.fileBookmark else {
            fileAvailable = paste.type == .text
            return
        }
        // Run async to not block UI
        DispatchQueue.global(qos: .userInitiated).async {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                DispatchQueue.main.async { fileAvailable = false }
                return
            }
            let accessGranted = url.startAccessingSecurityScopedResource()
            let exists = accessGranted && FileManager.default.fileExists(atPath: url.path)
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
            DispatchQueue.main.async { fileAvailable = exists }
        }
    }

    private func relinkFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select the file to re-link: \(paste.fileName ?? paste.title)"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let bookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                paste.fileBookmark = bookmark
                paste.fileName = url.lastPathComponent
                paste.content = url.path
                fileAvailable = true
                AppState.save(modelContext, operation: "relink file")
            } catch {
                logger.error("Failed to create bookmark for relinked file: \(error.localizedDescription)")
            }
        }
    }

    private func resolveBookmark(_ bookmark: Data) -> URL? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                logger.warning("Bookmark stale for: \(paste.title). File may have moved.")
            }
            return url
        } catch {
            logger.error("Bookmark resolution failed for: \(paste.title) - \(error.localizedDescription)")
            return nil
        }
    }
}

