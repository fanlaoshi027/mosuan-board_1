import CoreGraphics
import Foundation

/// Geometry-only support for editing a single Polygon vertex.
///
/// This type deliberately knows nothing about AppKit/Metal input events. It keeps
/// vertex editing separate from whole-object transforms so the same rules can be
/// reused by mouse, tablet and future touch input.
struct PolygonVertexEditor {
    static let defaultHitTolerance: CGFloat = 14

    struct Hit: Equatable {
        let objectID: UUID
        let vertexIndex: Int
        let distance: CGFloat
    }

    /// Finds the closest visible vertex among the supplied polygon objects.
    /// `visibleVertices` must already be in view/canvas coordinates.
    static func nearestVertex(
        point: CGPoint,
        polygons: [(id: UUID, vertices: [CGPoint])],
        tolerance: CGFloat = defaultHitTolerance
    ) -> Hit? {
        var best: Hit?
        let limit = max(1, tolerance)
        for polygon in polygons {
            for (index, vertex) in polygon.vertices.enumerated() {
                let distance = hypot(point.x - vertex.x, point.y - vertex.y)
                guard distance <= limit else { continue }
                if best == nil || distance < best!.distance {
                    best = Hit(objectID: polygon.id, vertexIndex: index, distance: distance)
                }
            }
        }
        return best
    }

    /// Converts a point from transformed canvas coordinates back into the
    /// polygon's local geometry coordinates.
    static func localPoint(_ point: CGPoint, for transform: GraphicObject.Transform) -> CGPoint {
        let translated = CGPoint(
            x: point.x - transform.position.x - transform.rotationCenter.x,
            y: point.y - transform.position.y - transform.rotationCenter.y
        )
        let c = cos(-transform.rotation)
        let s = sin(-transform.rotation)
        let unrotated = CGPoint(
            x: translated.x * c - translated.y * s,
            y: translated.x * s + translated.y * c
        )
        let sx = abs(transform.scale.width) > 0.0001 ? transform.scale.width : 1
        let sy = abs(transform.scale.height) > 0.0001 ? transform.scale.height : 1
        return CGPoint(x: unrotated.x / sx + transform.rotationCenter.x,
                       y: unrotated.y / sy + transform.rotationCenter.y)
    }

    /// Returns a copy of the object's polygon geometry with exactly one vertex
    /// replaced. No other geometry or transform field is changed.
    static func replacingVertex(
        in object: GraphicObject,
        index: Int,
        canvasPoint: CGPoint
    ) -> GraphicObject? {
        guard object.kind == .polygon,
              object.geometry.points.indices.contains(index) else { return nil }

        var updated = object
        updated.geometry.points[index] = localPoint(canvasPoint, for: object.transform)
        return updated
    }
}
