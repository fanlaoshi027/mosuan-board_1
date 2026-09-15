import Foundation

/// Versioned payload for copying mixed Mosuan selections between board views.
struct SelectionClipboardPayload: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = Self.currentVersion
    var strokes: [CanvasStroke] = []
    var objects: [GraphicObject] = []

    var isEmpty: Bool { strokes.isEmpty && objects.isEmpty }
}
