//
//  SettingsView.swift
//  Repaste
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import ServiceManagement
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.repaste", category: "Settings")

struct PointerCursor: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

extension View {
    func pointerCursor() -> some View {
        modifier(PointerCursor())
    }
}

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case solidLight = "Solid Light"
    case solidDark = "Solid Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light, .solidLight: return .light
        case .dark, .solidDark: return .dark
        }
    }

    var isSolid: Bool {
        self == .solidLight || self == .solidDark
    }
}

// MARK: - Export/Import Models

struct ExportData: Codable {
    let version: Int
    let exportedAt: Date
    let phrases: [ExportedPhrase]
    let tags: [ExportedTag]?
}

struct ExportedPhrase: Codable {
    let title: String
    let content: String
    let type: String
    let order: Int
    let isPinned: Bool
    let pinnedAt: Date?
    let fileName: String?
    let createdAt: Date
    let tags: [String]
}

struct ExportedTag: Codable {
    let name: String
    let color: String
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query private var allPastes: [Phrase]
    @Query private var allTags: [Tag]

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("previewLineCount") private var previewLineCount = 1
    @AppStorage("windowHeight") private var windowHeight: Double = 400
    @AppStorage("hideDockIcon") private var hideDockIcon = false
    @AppStorage("copySound") private var copySound = "Glass"
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false

    @State private var showDeleteConfirmation = false
    @State private var showImportAlert = false
    @State private var importAlertMessage = ""
    @State private var showAdvanced = false

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    logger.error("Failed to update launch at login: \(error.localizedDescription)")
                }
            }
        )
    }

    var body: some View {
        Form {
            Section("General") {
                Picker("Theme", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .onChange(of: appearanceMode) {
                    AppState.updateAppearance()
                }
                Picker("Preview Lines", selection: $previewLineCount) {
                    Text("None").tag(0)
                    ForEach(1...3, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                Picker("Sound on Copy", selection: $copySound) {
                    Text("Glass").tag("Glass")
                    Text("Pop").tag("Pop")
                    Text("Funk").tag("Funk")
                    Text("Basso").tag("Basso")
                    Divider()
                    Text("Off").tag("")
                }
                .onChange(of: copySound) { _, newSound in
                    if !newSound.isEmpty {
                        NSSound(named: .init(newSound))?.play()
                    }
                }
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        showAdvanced.toggle()
                    }
                } label: {
                    HStack {
                        Text("Advanced Features")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(showAdvanced ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if showAdvanced {
                    LabeledContent("Window Height") {
                        HStack {
                            Slider(value: $windowHeight, in: 300...600, step: 50)
                                .frame(width: 120)
                            Text("\(Int(windowHeight))")
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                    Toggle("Show Dock Icon", isOn: Binding(
                        get: { !hideDockIcon },
                        set: { hideDockIcon = !$0 }
                    ))
                    .onChange(of: hideDockIcon) {
                        updateDockIcon()
                    }
                    Toggle("Launch at Login", isOn: launchAtLoginBinding)
                }
            }

            Section {
                LabeledContent("Tags") {
                    Button("Manage") {
                        openWindow(id: "tag-manager")
                    }
                }

                LabeledContent("Usage Stats") {
                    Button("View") {
                        openWindow(id: "usage-stats")
                    }
                }

                LabeledContent("JSON") {
                    HStack {
                        Button("Export") {
                            exportPhrases()
                        }
                        .disabled(allPastes.isEmpty)
                        .accessibilityLabel("Export phrases to JSON")

                        Button("Import") {
                            importPhrases()
                        }
                        .accessibilityLabel("Import phrases from JSON")

                        Button("Delete All") {
                            showDeleteConfirmation = true
                        }
                        .foregroundStyle(.red)
                        .disabled(allPastes.isEmpty && allTags.isEmpty)
                        .accessibilityLabel("Delete all data")
                    }
                }
            } header: {
                Text("Data")
            } footer: {
                Text("Usage stats are private and stored locally. File references may need to be re-linked after import.")
            }

            Section {
                Toggle("iCloud Sync", isOn: $iCloudSyncEnabled)
                Toggle("Require Authentication", isOn: $biometricLockEnabled)
            } header: {
                Text("Security")
            } footer: {
                Text("iCloud sync changes require app restart. Use Touch ID or device passcode to unlock.")
            }

            Section("Contact") {
                Link(destination: URL(string: "https://mlot.ai/")!) {
                    HStack {
                        Text("Developer Site")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .pointerCursor()
                Link(destination: URL(string: "mailto:max@mlot.ai")!) {
                    HStack {
                        Text("Email")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .pointerCursor()
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 600)
        .onAppear {
            AppState.updateAppearance()
        }
        .confirmationDialog("Delete All Data?", isPresented: $showDeleteConfirmation) {
            Button("Delete All", role: .destructive) {
                deleteAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteConfirmationMessage)
        }
        .alert("Import Complete", isPresented: $showImportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importAlertMessage)
        }
    }

    // MARK: - Export

    private func exportPhrases() {
        let exportData = ExportData(
            version: 1,
            exportedAt: Date(),
            phrases: allPastes.map { phrase in
                ExportedPhrase(
                    title: phrase.title,
                    content: phrase.content,
                    type: phrase.type.rawValue,
                    order: phrase.order,
                    isPinned: phrase.isPinned,
                    pinnedAt: phrase.pinnedAt,
                    fileName: phrase.fileName,
                    createdAt: phrase.createdAt,
                    tags: phrase.tags
                )
            },
            tags: allTags.map { tag in
                ExportedTag(name: tag.name, color: tag.color)
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let jsonData: Data
        do {
            jsonData = try encoder.encode(exportData)
        } catch {
            logger.error("Failed to encode export data: \(error.localizedDescription)")
            importAlertMessage = "Export failed: Could not encode data."
            showImportAlert = true
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "repaste-export.json"
        panel.title = "Export Phrases"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try jsonData.write(to: url)
            } catch {
                logger.error("Failed to write export file: \(error.localizedDescription)")
                importAlertMessage = "Export failed: Could not write file."
                showImportAlert = true
            }
        }
    }

    // MARK: - Import

    private func importPhrases() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.title = "Import Phrases"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let exportData = try decoder.decode(ExportData.self, from: data)

                let maxOrder = allPastes.map(\.order).max() ?? 0
                var importedCount = 0

                // Import tags first (skip duplicates)
                var importedTagCount = 0
                for exportedTag in exportData.tags ?? [] {
                    if !allTags.contains(where: { $0.name == exportedTag.name }) {
                        let tag = Tag(name: exportedTag.name, color: exportedTag.color)
                        modelContext.insert(tag)
                        importedTagCount += 1
                    }
                }

                // Import phrases
                for (index, exported) in exportData.phrases.enumerated() {
                    let phrase = Phrase(
                        title: exported.title,
                        content: exported.content,
                        type: PhraseType(rawValue: exported.type) ?? .text,
                        order: maxOrder + index + 1
                    )
                    phrase.isPinned = exported.isPinned
                    phrase.pinnedAt = exported.pinnedAt
                    phrase.fileName = exported.fileName
                    phrase.tags = exported.tags
                    modelContext.insert(phrase)
                    importedCount += 1
                }

                AppState.save(modelContext, operation: "import phrases")
                let tagMsg = importedTagCount > 0 ? " and \(importedTagCount) tag\(importedTagCount == 1 ? "" : "s")" : ""
                importAlertMessage = "Successfully imported \(importedCount) phrase\(importedCount == 1 ? "" : "s")\(tagMsg)."
                showImportAlert = true
            } catch {
                importAlertMessage = "Failed to import: \(error.localizedDescription)"
                showImportAlert = true
            }
        }
    }

    // MARK: - Actions

    private var deleteConfirmationMessage: String {
        var parts: [String] = []
        if !allPastes.isEmpty {
            parts.append("\(allPastes.count) phrase\(allPastes.count == 1 ? "" : "s")")
        }
        if !allTags.isEmpty {
            parts.append("\(allTags.count) tag\(allTags.count == 1 ? "" : "s")")
        }
        let items = parts.joined(separator: " and ")
        return "This will permanently delete \(items). This action cannot be undone."
    }

    private func deleteAllData() {
        for phrase in allPastes {
            modelContext.delete(phrase)
        }
        for tag in allTags {
            modelContext.delete(tag)
        }
        AppState.save(modelContext, operation: "delete all data")
    }

    private func updateDockIcon() {
        NSApp.setActivationPolicy(hideDockIcon ? .accessory : .regular)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Phrase.self, Tag.self, UsageEvent.self], inMemory: true)
}
