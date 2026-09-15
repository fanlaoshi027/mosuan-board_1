import Foundation

/// A lightweight reference to the original PDF. The PDF itself is never copied into the note by default.
struct PDFDocument: Codable, Equatable, Identifiable {
    let id: UUID
    var filePath: String
    var fileName: String
    var pageCount: Int
    var currentPage: Int

    init(id: UUID = UUID(), filePath: String, fileName: String, pageCount: Int = 0, currentPage: Int = 1) {
        self.id = id
        self.filePath = filePath
        self.fileName = fileName
        self.pageCount = pageCount
        self.currentPage = currentPage
    }
}

/// One editable layer. Page content is kept as vector ink/objects, so a note stays small and editable.
struct BoardLayer: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var isVisible: Bool
    var isLocked: Bool
    var isBase: Bool
    var pageStates: [Int: CanvasPageState]

    init(id: UUID = UUID(), name: String, isVisible: Bool = true, isLocked: Bool = false, isBase: Bool = false) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.isBase = isBase
        self.pageStates = [:]
    }
}

struct BoardNote: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var pdf: PDFDocument?
    var layers: [BoardLayer]
    var currentLayerID: UUID
    var currentPage: Int

    init(name: String = "未命名笔记", pdf: PDFDocument? = nil) {
        self.id = UUID()
        self.name = name
        self.pdf = pdf
        let layer = BoardLayer(name: "笔记")
        self.layers = [layer]
        self.currentLayerID = layer.id
        self.currentPage = 1
    }

    var currentLayer: BoardLayer? { layers.first(where: { $0.id == currentLayerID }) }
}
