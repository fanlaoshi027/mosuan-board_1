import CoreGraphics
import Foundation

/// Stateful construction model for the polygon/triangle tool.
///
/// The model deliberately contains no UI or renderer code. The canvas can feed
/// pointer locations into it and use `previewVertices` while the polygon is
/// being constructed. A polygon is committed when the pointer returns near the
/// first vertex after at least three distinct vertices have been added.
struct PolygonToolModel {
    private(set) var vertices: [CGPoint] = []
    private(set) var isConstructing = false

    var closeTolerance: CGFloat = 14
    var minimumVertexDistance: CGFloat = 8
    var maximumVertices: Int = 256

    var isTriangle: Bool { vertices.count == 3 }
    var canCommit: Bool { vertices.count >= 3 }

    var previewVertices: [CGPoint] { vertices }

    mutating func begin(at point: CGPoint) {
        vertices = [point]
        isConstructing = true
    }

    /// Adds a vertex unless it is too close to the previous vertex.
    /// Returns false when the point is ignored.
    @discardableResult
    mutating func append(at point: CGPoint) -> Bool {
        guard isConstructing, vertices.count < maximumVertices else { return false }
        if let last = vertices.last,
           distance(last, point) < minimumVertexDistance {
            return false
        }
        vertices.append(point)
        return true
    }

    /// Returns true when the point closes the polygon at the first vertex.
    /// The first vertex itself is not duplicated in the returned geometry.
    @discardableResult
    mutating func closeIfNearFirst(at point: CGPoint) -> Bool {
        guard isConstructing, canCommit, let first = vertices.first else { return false }
        guard distance(first, point) <= closeTolerance else { return false }
        isConstructing = false
        return true
    }

    mutating func cancel() {
        vertices.removeAll(keepingCapacity: true)
        isConstructing = false
    }

    mutating func finish() -> [CGPoint]? {
        guard canCommit else {
            cancel()
            return nil
        }
        let result = vertices
        cancel()
        return result
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
