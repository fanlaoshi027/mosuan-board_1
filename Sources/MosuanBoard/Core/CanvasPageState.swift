import Foundation

struct CanvasStroke: Codable, Equatable, Identifiable { let id: UUID; var points: [InkPoint]; var style: PenStyle; var rotation: Float; init(id: UUID = UUID(), points: [InkPoint], style: PenStyle, rotation: Float = 0) { self.id = id; self.points = points; self.style = style; self.rotation = rotation } }
struct CanvasPageState: Codable, Equatable {
    var strokes: [CanvasStroke] = []
    var objects: [GraphicObject] = []
    init(strokes: [CanvasStroke] = [], objects: [GraphicObject] = []) { self.strokes = strokes; self.objects = objects }
    private enum CodingKeys: String, CodingKey { case strokes, objects }
    init(from decoder: Decoder) throws { let container = try decoder.container(keyedBy: CodingKeys.self); strokes = try container.decodeIfPresent([CanvasStroke].self, forKey: .strokes) ?? []; objects = try container.decodeIfPresent([GraphicObject].self, forKey: .objects) ?? [] }
}
