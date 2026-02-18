//
//  StatsView.swift
//  Repaste
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

// MARK: - Export Model

struct StatsExportData: Codable {
    let exportedAt: Date
    let events: [ExportedEvent]
}

struct ExportedEvent: Codable {
    let copiedAt: Date
    let title: String
    let type: String
}

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UsageEvent.copiedAt, order: .reverse) private var allEvents: [UsageEvent]

    @State private var showDeleteConfirmation = false

    private var totalCopies: Int {
        allEvents.count
    }

    private var textCopies: Int {
        allEvents.filter { $0.type == .text }.count
    }

    private var fileCopies: Int {
        allEvents.filter { $0.type == .file }.count
    }

    private var mostUsed: [(title: String, count: Int)] {
        let grouped = Dictionary(grouping: allEvents, by: { $0.title })
        return grouped
            .map { (title: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }

    private var recentlyUsed: [UsageEvent] {
        Array(allEvents.prefix(5))
    }

    var body: some View {
        Form {
            Section("Overview") {
                LabeledContent("Total Copies", value: "\(totalCopies)")
                LabeledContent("Text", value: "\(textCopies)")
                LabeledContent("Files", value: "\(fileCopies)")
            }

            Section("Most Used") {
                if mostUsed.isEmpty {
                    Text("No usage data yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(mostUsed, id: \.title) { item in
                        LabeledContent(item.title, value: "\(item.count)")
                    }
                }
            }

            Section("Recently Used") {
                if recentlyUsed.isEmpty {
                    Text("No recent activity")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentlyUsed) { event in
                        LabeledContent(event.title, value: formatDate(event.copiedAt))
                    }
                }
            }

            Section {
                LabeledContent("Data") {
                    HStack {
                        Button("Export") {
                            exportStats()
                        }
                        .disabled(allEvents.isEmpty)

                        Button("Delete All") {
                            showDeleteConfirmation = true
                        }
                        .foregroundStyle(.red)
                        .disabled(allEvents.isEmpty)
                    }
                }
            } header: {
                Text("Manage")
            } footer: {
                Text("Export or delete usage data only. Your pastes will not be affected.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 400)
        .confirmationDialog("Delete Usage Data?", isPresented: $showDeleteConfirmation) {
            Button("Delete All Usage Data", role: .destructive) {
                deleteUsageData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all usage history. Your pastes will not be deleted.")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func exportStats() {
        let exportData = StatsExportData(
            exportedAt: Date(),
            events: allEvents.map { event in
                ExportedEvent(
                    copiedAt: event.copiedAt,
                    title: event.title,
                    type: event.typeRaw
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(exportData) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "repaste-usage-stats.json"
        panel.title = "Export Usage Stats"

        if panel.runModal() == .OK, let url = panel.url {
            try? jsonData.write(to: url)
        }
    }

    private func deleteUsageData() {
        for event in allEvents {
            modelContext.delete(event)
        }
        AppState.save(modelContext, operation: "delete usage data")
    }
}

#Preview {
    StatsView()
        .modelContainer(for: [Phrase.self, Tag.self, UsageEvent.self], inMemory: true)
}
