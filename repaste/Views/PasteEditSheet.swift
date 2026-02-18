//
//  PasteEditSheet.swift
//  Repaste
//

import SwiftUI
import SwiftData
import AppKit
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.repaste", category: "PasteEdit")

struct PasteEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPastes: [Phrase]
    @Query private var allTagObjects: [Tag]

    private var existingPaste: Phrase? { AppState.shared.editingPaste }
    private var isEditing: Bool { existingPaste != nil }

    @State private var title = ""
    @State private var content = ""
    @State private var pasteType: PhraseType = .text
    @State private var fileURL: URL?
    @State private var fileBookmark: Data?
    @State private var tags: [String] = []
    @State private var newTagText = ""
    @State private var showNewTagField = false
    @FocusState private var isNewTagFocused: Bool

    // Single source of truth: Tag objects table
    private var allAvailableTags: [String] {
        allTagObjects.map(\.name).sorted()
    }

    // Get color for a tag name (default matches Tag.init default: #007AFF)
    private func colorForTag(_ name: String) -> Color {
        allTagObjects.first { $0.name == name }?.swiftUIColor ?? Color(hex: "#007AFF") ?? .blue
    }

    // Create or get Tag object
    private func ensureTagExists(_ name: String) {
        if !allTagObjects.contains(where: { $0.name == name }) {
            let tag = Tag(name: name)
            modelContext.insert(tag)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("General") {
                        TextField("Name", text: $title)
                            .textFieldStyle(.plain)
                        Picker("Type", selection: $pasteType) {
                            Text("Text").tag(PhraseType.text)
                            Text("File").tag(PhraseType.file)
                        }
                        .pickerStyle(.segmented)

                        // Tags picker
                        HStack {
                            Text("Tags")
                            Spacer()
                            Menu {
                                ForEach(allAvailableTags, id: \.self) { tag in
                                    Button {
                                        if tags.contains(tag) {
                                            tags.removeAll { $0 == tag }
                                        } else {
                                            tags.append(tag)
                                        }
                                    } label: {
                                        HStack {
                                            Circle()
                                                .fill(colorForTag(tag))
                                                .frame(width: 10, height: 10)
                                            Text(tag)
                                            Spacer()
                                            if tags.contains(tag) {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }

                                if !allAvailableTags.isEmpty {
                                    Divider()
                                }

                                Button("New Tag") {
                                    showNewTagField = true
                                }
                            } label: {
                                Text("Add")
                            }
                        }

                        // New tag input
                        if showNewTagField {
                            HStack {
                                TextField("New Tag", text: $newTagText)
                                    .textFieldStyle(.plain)
                                    .focused($isNewTagFocused)
                                    .onSubmit {
                                        createAndSelectTag()
                                    }
                                    .onAppear {
                                        // Delay to allow view to render before focusing
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            isNewTagFocused = true
                                        }
                                    }
                                Button("Done") {
                                    createAndSelectTag()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }

                        // Selected tags as pills
                        if !tags.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(colorForTag(tag))
                                            .frame(width: 8, height: 8)
                                        Text(tag)
                                        Button {
                                            tags.removeAll { $0 == tag }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .font(.callout)
                                    .padding(.leading, 6)
                                    .padding(.trailing, 3)
                                    .padding(.vertical, 3)
                                    .background(colorForTag(tag).opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 999))
                                }
                            }
                        }
                    }

                    if pasteType == .text {
                        Section("Content") {
                            TextEditor(text: $content)
                                .font(.body)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: NSFont.systemFont(ofSize: NSFont.systemFontSize).boundingRectForFont.height * 3)
                        }
                    } else {
                        Section("File") {
                            HStack {
                                Image(systemName: fileURL == nil ? "doc.badge.plus" : "doc.fill")
                                    .foregroundColor(fileURL == nil ? .secondary : .blue)

                                Text(fileURL?.lastPathComponent ?? "No file selected")
                                    .foregroundStyle(fileURL == nil ? .secondary : .primary)

                                Spacer()

                                Button("Browse...") {
                                    chooseFile()
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)

                Divider()

                HStack {
                    Button("Cancel") {
                        closeWindow()
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Spacer()

                    Button("Save") {
                        save()
                        closeWindow()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                }
                .padding()
            }
            .frame(minWidth: 400, minHeight: 400)
            .navigationTitle(isEditing ? "Repaste: Edit" : "Repaste: Add")
        }
        .onAppear {
            resetForm()
        }
        .onChange(of: isNewTagFocused) { _, focused in
            if !focused && showNewTagField {
                createAndSelectTag()
            }
        }
    }

    private func closeWindow() {
        AppState.shared.clearEditing()
        NSApplication.shared.keyWindow?.close()
    }

    private func createAndSelectTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            showNewTagField = false
            return
        }
        // Create tag in table if it doesn't exist
        ensureTagExists(trimmed)
        AppState.save(modelContext, operation: "create tag")
        // Select it for this phrase
        if !tags.contains(trimmed) {
            tags.append(trimmed)
        }
        newTagText = ""
        showNewTagField = false
    }

    // MARK: - Validation

    private var isValid: Bool {
        if title.isEmpty { return false }
        if pasteType == .text && content.isEmpty { return false }
        if pasteType == .file && fileURL == nil { return false }
        return true
    }

    // MARK: - Actions

    private func resetForm() {
        if let paste = existingPaste {
            title = paste.title
            content = paste.content
            pasteType = paste.type
            tags = paste.tags
            if let bookmark = paste.fileBookmark {
                fileBookmark = bookmark
                var isStale = false
                fileURL = try? URL(
                    resolvingBookmarkData: bookmark,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                if isStale {
                    logger.warning("Bookmark is stale for paste: \(paste.title). File may have moved.")
                }
            } else {
                fileURL = nil
                fileBookmark = nil
            }
        } else {
            title = ""
            content = ""
            pasteType = .text
            fileURL = nil
            fileBookmark = nil
            tags = []
        }
        newTagText = ""
        showNewTagField = false
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            fileURL = url
            do {
                fileBookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch {
                logger.error("Failed to create bookmark for file: \(error.localizedDescription)")
                fileBookmark = nil
            }
            if title.isEmpty {
                title = url.deletingPathExtension().lastPathComponent
            }
        }
    }

    private func save() {
        // Ensure all tags exist as Tag objects
        for tagName in tags {
            ensureTagExists(tagName)
        }

        if let paste = existingPaste {
            // Update existing
            paste.title = title
            paste.content = pasteType == .text ? content : (fileURL?.path ?? "")
            paste.type = pasteType
            paste.fileName = fileURL?.lastPathComponent
            paste.fileBookmark = fileBookmark
            paste.tags = tags
        } else {
            // Create new - order at bottom (highest number, chronological)
            let maxOrder = allPastes.map(\.order).max() ?? 0
            let paste = Phrase(
                title: title,
                content: pasteType == .text ? content : (fileURL?.path ?? ""),
                type: pasteType,
                order: maxOrder + 1
            )
            paste.fileName = fileURL?.lastPathComponent
            paste.fileBookmark = fileBookmark
            paste.tags = tags
            modelContext.insert(paste)
        }
        AppState.save(modelContext, operation: "save phrase")
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

#Preview {
    PasteEditSheet()
        .modelContainer(for: [Phrase.self, Tag.self, UsageEvent.self], inMemory: true)
}
