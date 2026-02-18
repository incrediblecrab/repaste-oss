//
//  ClipboardService.swift
//  Repaste
//

import AppKit

final class ClipboardService {
    static let shared = ClipboardService()

    private init() {}

    func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func copyFile(at url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([url as NSURL])
    }
}
