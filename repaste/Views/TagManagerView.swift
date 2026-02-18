//
//  TagManagerView.swift
//  Repaste
//

import SwiftUI
import SwiftData
import AppKit

struct TagManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTags: [Tag]
    @Query private var allPhrases: [Phrase]

    @State private var showAddTag = false
    @State private var newTagName = ""
    @State private var newTagColor = Color.blue
    @State private var colorPickerTagId: UUID?
    @State private var showNewColorPicker = false
    @State private var editingTagId: UUID?
    @State private var editingTagName = ""
    @FocusState private var isAddTagFocused: Bool
    @FocusState private var isEditTagFocused: Bool

    private let palette: [Color] = [.red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown]

    private var nextAutoColor: Color {
        let usedColors = Set(allTags.map { $0.color })
        for color in palette {
            if !usedColors.contains(color.toHex()) {
                return color
            }
        }
        // All colors used, cycle based on count
        return palette[allTags.count % palette.count]
    }

    var body: some View {
        Form {
            Section {
                ForEach(allTags) { tag in
                    if editingTagId == tag.id {
                        HStack {
                            colorCircle(color: tag.swiftUIColor, tagId: tag.id)
                            TextField("Name", text: $editingTagName)
                                .textFieldStyle(.plain)
                                .focused($isEditTagFocused)
                                .onSubmit {
                                    saveEditedTag(tag)
                                }
                                .onExitCommand {
                                    cancelEditTag()
                                }
                        }
                    } else {
                        HStack {
                            colorCircle(color: tag.swiftUIColor, tagId: tag.id)
                            Text(tag.name)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button {
                                startEditingTag(tag)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                deleteTag(tag)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                if showAddTag {
                    HStack {
                        Circle()
                            .fill(newTagColor)
                            .frame(width: 12, height: 12)
                            .onTapGesture {
                                showNewColorPicker.toggle()
                            }
                            .popover(isPresented: $showNewColorPicker) {
                                colorPaletteView { color in
                                    newTagColor = color
                                    showNewColorPicker = false
                                }
                            }
                        TextField("Name", text: $newTagName)
                            .textFieldStyle(.plain)
                            .focused($isAddTagFocused)
                            .onSubmit {
                                addTag()
                            }
                            .onExitCommand {
                                cancelAddTag()
                            }
                    }
                } else {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Add Tag")
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        newTagColor = nextAutoColor
                        showAddTag = true
                        // Delay to allow view to render before focusing
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isAddTagFocused = true
                        }
                    }
                }
            } header: {
                Text("Tags")
            } footer: {
                Text("Click color to change • Right-click tag to edit or delete")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 400)
        .onChange(of: isEditTagFocused) { _, focused in
            if !focused, let tagId = editingTagId, let tag = allTags.first(where: { $0.id == tagId }) {
                saveEditedTag(tag)
            }
        }
        .onChange(of: isAddTagFocused) { _, focused in
            if !focused && showAddTag {
                addTag()
            }
        }
    }

    @ViewBuilder
    private func colorCircle(color: Color, tagId: UUID) -> some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .onTapGesture {
                colorPickerTagId = tagId
            }
            .popover(isPresented: Binding(
                get: { colorPickerTagId == tagId },
                set: { if !$0 { colorPickerTagId = nil } }
            )) {
                colorPaletteView { newColor in
                    updateTagColor(tagId: tagId, color: newColor)
                    colorPickerTagId = nil
                }
            }
    }

    @ViewBuilder
    private func colorPaletteView(onSelect: @escaping (Color) -> Void) -> some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { col in
                        let index = row * 4 + col
                        Circle()
                            .fill(palette[index])
                            .frame(width: 24, height: 24)
                            .onTapGesture {
                                onSelect(palette[index])
                            }
                    }
                }
            }
        }
        .padding()
    }

    private func updateTagColor(tagId: UUID, color: Color) {
        guard let tag = allTags.first(where: { $0.id == tagId }) else { return }
        tag.color = color.toHex()
        AppState.save(modelContext, operation: "update tag color")
    }

    private func addTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            cancelAddTag()
            return
        }
        guard !allTags.contains(where: { $0.name == trimmed }) else {
            cancelAddTag()
            return
        }

        let tag = Tag(name: trimmed, color: newTagColor.toHex())
        modelContext.insert(tag)
        AppState.save(modelContext, operation: "add tag")

        newTagName = ""
        newTagColor = nextAutoColor
        showAddTag = false
    }

    private func cancelAddTag() {
        newTagName = ""
        newTagColor = nextAutoColor
        showAddTag = false
    }

    private func startEditingTag(_ tag: Tag) {
        editingTagId = tag.id
        editingTagName = tag.name
        // Delay to allow view to render before focusing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isEditTagFocused = true
        }
    }

    private func saveEditedTag(_ tag: Tag) {
        let trimmed = editingTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            cancelEditTag()
            return
        }

        let oldName = tag.name
        for phrase in allPhrases {
            if let index = phrase.tags.firstIndex(of: oldName) {
                phrase.tags[index] = trimmed
            }
        }
        tag.name = trimmed
        AppState.save(modelContext, operation: "rename tag")
        cancelEditTag()
    }

    private func cancelEditTag() {
        editingTagId = nil
        editingTagName = ""
    }

    private func deleteTag(_ tag: Tag) {
        for phrase in allPhrases {
            phrase.tags.removeAll { $0 == tag.name }
        }
        modelContext.delete(tag)
        AppState.save(modelContext, operation: "delete tag")
    }
}

#Preview {
    TagManagerView()
        .modelContainer(for: [Phrase.self, Tag.self, UsageEvent.self], inMemory: true)
}
