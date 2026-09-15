import AppKit
import Foundation
import UniformTypeIdentifiers

struct PDFNoteIO {
    static func save(_ note: BoardNote, suggestedName: String = "未命名笔记") -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "mosuan") ?? .data]
        panel.nameFieldStringValue = suggestedName.hasSuffix(".mosuan") ? suggestedName : suggestedName + ".mosuan"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            let data = try JSONEncoder().encode(note)
            try data.write(to: url, options: .atomic)
            return url
        } catch { return nil }
    }

    static func open(_ url: URL) -> BoardNote? {
        do { return try JSONDecoder().decode(BoardNote.self, from: Data(contentsOf: url)) }
        catch { return nil }
    }
}
