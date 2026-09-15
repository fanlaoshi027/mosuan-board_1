import CoreGraphics
import Foundation

/// A first-class straight line used by the drawing tools.
/// Geometry is stored as two world-space points; rendering and transforms can be
/// applied independently without degrading the original geometry.
struct StructuredLine: Identifiable, Codable, Equatable {
    let id: UUID
    var start: CGPoint
    var end: CGPoint
    var style: GraphicObject.Style

    init(
        id: UUID = UUID(),
        start: CGPoint,
        end: CGPoint,
        style: GraphicObject.Style = GraphicObject.Style()
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.style = style
    }

    var length: CGFloat {
        hypot(end.x - start.x, end.y - start.y)
    }

    var midpoint: CGPoint {
        CGPoint(x: (start.x + end.x) * 0.5, y: (start.y + end.y) * 0.5)
    }

    var bounds: CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        ).insetBy(dx: -style.strokeWidth, dy: -style.strokeWidth)
    }

    func contains(_ point: CGPoint, tolerance: CGFloat = 10) -> Bool {
        LineGeometry.hitTest(
            point: point,
            start: start,
            end: end,
            tolerance: tolerance + style.strokeWidth
        )
    }

    func movedEndpoint(_ endpoint: Int, to point: CGPoint) -> StructuredLine {
        var copy = self
        if endpoint == 0 {
            copy.start = point
        } else if endpoint == 1 {
            copy.end = point
        }
        return copy
    }

    func asGraphicObject() -> GraphicObject {
        GraphicObject.line(from: start, to: end, style: style)
    }

    static func from(_ object: GraphicObject) -> StructuredLine? {
        guard object.kind == .line, object.geometry.points.count >= 2 else { return nil }
        return StructuredLine(
            id: object.id,
            start: object.geometry.points[0],
            end: object.geometry.points[1],
            style: object.style
        )
    }
}
