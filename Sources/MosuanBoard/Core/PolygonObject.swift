import CoreGraphics
import Foundation

/// First-class closed polygon geometry used by triangles and future geometry tools.
/// Vertices stay in world coordinates; style and transforms are inherited from
/// GraphicObject so the same selection/transform pipeline can be reused.
struct PolygonObject: Identifiable, Codable, Equatable {
    let id: UUID
    var vertices: [CGPoint]
    var style: GraphicObject.Style
    var isClosed: Bool

    init(
        id: UUID = UUID(),
        vertices: [CGPoint],
        style: GraphicObject.Style = GraphicObject.Style(),
        isClosed: Bool = true
    ) {
        self.id = id
        self.vertices = vertices
        self.style = style
        self.isClosed = isClosed
    }

    var isValid: Bool {
        vertices.count >= 3 && vertices.count <= 256
    }

    var bounds: CGRect? {
        guard let first = vertices.first else { return nil }
        var result = CGRect(origin: first, size: .zero)
        for point in vertices.dropFirst() {
            result = result.union(CGRect(origin: point, size: .zero))
        }
        return result.insetBy(dx: -style.strokeWidth, dy: -style.strokeWidth)
    }

    func asGraphicObject() -> GraphicObject? {
        guard isValid else { return nil }
        return GraphicObject(
            id: id,
            kind: .polygon,
            style: style,
            geometry: GraphicObject.Geometry(points: vertices)
        )
    }

    static func from(_ object: GraphicObject) -> PolygonObject? {
        guard object.kind == .polygon, object.geometry.points.count >= 3 else { return nil }
        return PolygonObject(
            id: object.id,
            vertices: object.geometry.points,
            style: object.style
        )
    }

    func movedVertex(_ index: Int, to point: CGPoint) -> PolygonObject {
        var copy = self
        guard copy.vertices.indices.contains(index) else { return copy }
        copy.vertices[index] = point
        return copy
    }

    func containsEdge(_ point: CGPoint, tolerance: CGFloat = 10) -> Bool {
        guard vertices.count >= 2 else { return false }
        let edgeCount = isClosed ? vertices.count : vertices.count - 1
        guard edgeCount > 0 else { return false }
        for index in 0..<edgeCount {
            let next = (index + 1) % vertices.count
            if distance(point, toSegment: vertices[index], vertices[next]) <= tolerance + style.strokeWidth {
                return true
            }
        }
        return false
    }

    private func distance(_ point: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared == 0 {
            return hypot(point.x - a.x, point.y - a.y)
        }
        let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared))
        let projection = CGPoint(x: a.x + t * dx, y: a.y + t * dy)
        return hypot(point.x - projection.x, point.y - projection.y)
    }
}

extension PolygonObject {
    /// Convenience constructor for the most common math teaching shape.
    static func triangle(
        a: CGPoint,
        b: CGPoint,
        c: CGPoint,
        style: GraphicObject.Style = GraphicObject.Style()
    ) -> PolygonObject {
        PolygonObject(vertices: [a, b, c], style: style)
    }
}
