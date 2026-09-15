import CoreGraphics
import Foundation

/// Geometry helpers shared by the polygon/triangle tool and future structured shapes.
enum PolygonGeometry {
    static func isNear(_ a: CGPoint, _ b: CGPoint, tolerance: CGFloat) -> Bool {
        hypot(a.x - b.x, a.y - b.y) <= tolerance
    }

    static func contains(_ point: CGPoint, in polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let a = polygon[i]
            let b = polygon[j]
            if (a.y > point.y) != (b.y > point.y) {
                let denominator = b.y - a.y
                let x = (b.x - a.x) * (point.y - a.y) / denominator + a.x
                if point.x < x {
                    inside.toggle()
                }
            }
            j = i
        }
        return inside
    }

    static func nearestVertex(to point: CGPoint, in vertices: [CGPoint], tolerance: CGFloat = 14) -> Int? {
        var result: (index: Int, distance: CGFloat)?
        for (index, vertex) in vertices.enumerated() {
            let d = hypot(point.x - vertex.x, point.y - vertex.y)
            guard d <= tolerance else { continue }
            if result == nil || d < result!.distance {
                result = (index, d)
            }
        }
        return result?.index
    }

    static func triangle(first: CGPoint, second: CGPoint, third: CGPoint, style: GraphicObject.Style = .init()) -> GraphicObject {
        GraphicObject.polygon(points: [first, second, third], style: style)
    }
}
