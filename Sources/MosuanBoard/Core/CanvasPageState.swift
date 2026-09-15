import Foundation

/// Serializable vector ink state belonging to one document page.
struct CanvasStroke: Codable, Equatable, Identifiable {
    let id: UUID
    var points: [InkPoint]
    var style: PenStyle
    var rotation: Float

    init(id: UUID = UUID(), points: [InkPoint], style: PenStyle, rotation: Float = 0) {
        self.id = id
        self.points = points
        self.style = style
        self.rotation = rotation
    }
}

/// A page keeps legacy freehand strokes and structured graphic objects side by side.
/// This lets the new object model be introduced incrementally without breaking old data.
struct CanvasPageState: Codable, Equatable {
    var strokes: [CanvasStroke] = []
    var objects: [GraphicObject] = []

    init(strokes: [CanvasStroke] = [], objects: [GraphicObject] = []) {
        self.strokes = strokes
        self.objects = objects
    }

    private enum CodingKeys: String, CodingKey {
        case strokes
        case objects
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        strokes = try container.decodeIfPresent([CanvasStroke].self, forKey: .strokes) ?? []
        // Old page data has no objects key; treat it as an empty structured-object layer.
        objects = try container.decodeIfPresent([GraphicObject].self, forKey: .objects) ?? []
    }
}
