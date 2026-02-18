//
//  Phrase.swift
//  Repaste
//

import SwiftData
import SwiftUI
import Foundation

/// Represents a saved phrase that can be quickly copied to clipboard
@Model
final class Phrase {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    private var typeRaw: String = PhraseType.text.rawValue
    var order: Int = 0
    var createdAt: Date = Date()

    // Pin properties
    var isPinned: Bool = false
    var pinnedAt: Date?

    // File phrase properties
    var fileName: String?
    var fileBookmark: Data?

    // Tags for filtering
    var tags: [String] = []

    @Transient
    var type: PhraseType {
        get { PhraseType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }

    init(
        title: String,
        content: String,
        type: PhraseType = .text,
        order: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.typeRaw = type.rawValue
        self.order = order
        self.createdAt = Date()
        self.isPinned = false
        self.pinnedAt = nil
        self.tags = []
    }
}

/// The type of content stored in a phrase
enum PhraseType: String, Codable {
    case text
    case file
}

/// Tracks each copy event for usage statistics
@Model
final class UsageEvent {
    var id: UUID = UUID()
    var copiedAt: Date = Date()
    var title: String = ""
    var typeRaw: String = PhraseType.text.rawValue

    @Transient
    var type: PhraseType {
        get { PhraseType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }

    init(title: String, type: PhraseType) {
        self.id = UUID()
        self.copiedAt = Date()
        self.title = title
        self.typeRaw = type.rawValue
    }
}

/// A tag with customizable color
@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "#007AFF"

    init(name: String, color: String = "#007AFF") {
        self.id = UUID()
        self.name = name
        self.color = color
    }

    var swiftUIColor: Color {
        Color(hex: color) ?? .blue
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }

    func toHex() -> String {
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else {
            return "#007AFF"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
