import Foundation
import Combine

@MainActor
final class BoardLayerStore: ObservableObject {
    @Published private(set) var note: BoardNote

    init(note: BoardNote = BoardNote()) { self.note = note }
    var visibleLayers: [BoardLayer] { note.layers.filter(\.isVisible) }
    var currentLayer: BoardLayer? { note.currentLayer }

    func setNoteName(_ name: String) {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty { note.name = value }
    }
    func selectLayer(_ id: UUID) { guard note.layers.contains(where: { $0.id == id }) else { return }; note.currentLayerID = id }
    func addLayer(name: String? = nil) {
        let index = note.layers.filter { !$0.isBase }.count + 1
        let layer = BoardLayer(name: name ?? "图层 \(index)")
        note.layers.append(layer); note.currentLayerID = layer.id
    }
    func deleteCurrentLayer() {
        guard let index = note.layers.firstIndex(where: { $0.id == note.currentLayerID }), !note.layers[index].isBase else { return }
        note.layers.remove(at: index)
        note.currentLayerID = note.layers.last(where: { !$0.isBase })?.id ?? note.layers.first?.id ?? note.currentLayerID
    }
    func renameLayer(_ id: UUID, name: String) {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = note.layers.firstIndex(where: { $0.id == id }), !value.isEmpty else { return }
        note.layers[index].name = value
    }
    func toggleVisibility(_ id: UUID) { guard let index = note.layers.firstIndex(where: { $0.id == id }) else { return }; note.layers[index].isVisible.toggle() }
    func toggleLock(_ id: UUID) { guard let index = note.layers.firstIndex(where: { $0.id == id }), !note.layers[index].isBase else { return }; note.layers[index].isLocked.toggle() }
    func setPDF(_ pdf: PDFDocument) {
        note.pdf = pdf
        if let baseIndex = note.layers.firstIndex(where: { $0.isBase }) { note.layers[baseIndex].name = "PDF · \(pdf.fileName)" }
        else { note.layers.insert(BoardLayer(name: "PDF · \(pdf.fileName)", isLocked: true, isBase: true), at: 0) }
        note.currentPage = 1
    }
    func setRawCanvasBase() { note.pdf = nil; note.layers.removeAll(where: { $0.isBase }); note.currentPage = 1 }
    func setPage(_ page: Int) { guard page >= 1, pdfPageCount == 0 || page <= pdfPageCount else { return }; note.currentPage = page }
    var pdfPageCount: Int { note.pdf?.pageCount ?? 0 }
    func compositeState(page: Int) -> CanvasPageState {
        var strokes: [CanvasStroke] = [], objects: [GraphicObject] = []
        for layer in note.layers where layer.isVisible && !layer.isBase {
            let state = layer.pageStates[page] ?? CanvasPageState()
            strokes += state.strokes; objects += state.objects
        }
        return CanvasPageState(strokes: strokes, objects: objects)
    }
    func saveCurrentLayerState(_ composite: CanvasPageState, page: Int) {
        guard let index = note.layers.firstIndex(where: { $0.id == note.currentLayerID }), !note.layers[index].isBase, !note.layers[index].isLocked else { return }
        let other = note.layers.enumerated().filter { $0.offset != index && $0.element.isVisible }
        let otherStrokeIDs = Set(other.flatMap { $0.element.pageStates[page]?.strokes.map(\.id) ?? [] })
        let otherObjectIDs = Set(other.flatMap { $0.element.pageStates[page]?.objects.map(\.id) ?? [] })
        note.layers[index].pageStates[page] = CanvasPageState(strokes: composite.strokes.filter { !otherStrokeIDs.contains($0.id) }, objects: composite.objects.filter { !otherObjectIDs.contains($0.id) })
    }
}
