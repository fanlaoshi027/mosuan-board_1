import CoreGraphics
import Foundation

/// Pure interaction logic for direct and smart straight-line drawing.
/// The view layer remains responsible for pointer events and rendering.
struct LineInteractionModel {
    var pauseDelay: TimeInterval = 0.18
    var straightnessTolerance: CGFloat = 0.075
    var minimumLength: CGFloat = 24

    /// Returns true when a freehand path is sufficiently close to its end-to-end line.
    func isLikelyStraightLine(_ points: [InkPoint]) -> Bool {
        guard points.count >= 3,
              let first = points.first,
              let last = points.last else { return false }
        let a = CGPoint(x: CGFloat(first.x), y: CGFloat(first.y))
        let b = CGPoint(x: CGFloat(last.x), y: CGFloat(last.y))
        let length = hypot(b.x - a.x, b.y - a.y)
        guard length >= minimumLength else { return false }

        let maxDistance = length * straightnessTolerance
        return points.allSatisfy { point in
            distanceFromPoint(
                CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)),
                toSegment: a,
                b
            ) <= maxDistance
        }
    }

    func snappedLine(from points: [InkPoint]) -> [InkPoint]? {
        guard points.count >= 2, isLikelyStraightLine(points),
              let first = points.first, let last = points.last else { return nil }
        return [first, last]
    }

    /// Returns the endpoint closest to the pointer, or nil when neither is close enough.
    func nearestEndpoint(
        of points: [InkPoint],
        to point: CGPoint,
        tolerance: CGFloat = 14
    ) -> Int? {
        guard points.count >= 2 else { return nil }
        let candidates = [
            CGPoint(x: CGFloat(points[0].x), y: CGFloat(points[0].y)),
            CGPoint(x: CGFloat(points[points.count - 1].x), y: CGFloat(points[points.count - 1].y))
        ]
        var best: (index: Int, distance: CGFloat)?
        for (index, candidate) in candidates.enumerated() {
            let distance = hypot(candidate.x - point.x, candidate.y - point.y)
            guard distance <= tolerance else { continue }
            if best == nil || distance < best!.distance {
                best = (index, distance)
            }
        }
        return best?.index
    }

    /// Creates a two-point preview after dragging one endpoint.
    func movingEndpoint(
        of points: [InkPoint],
        endpoint: Int,
        to point: CGPoint
    ) -> [InkPoint] {
        guard points.count >= 2, endpoint == 0 || endpoint == 1 else { return points }
        var result = points
        let original = endpoint == 0 ? result[0] : result[result.count - 1]
        let replacement = InkPoint(
            x: Float(point.x),
            y: Float(point.y),
            pressure: original.pressure
        )
        if endpoint == 0 {
            result[0] = replacement
        } else {
            result[result.count - 1] = replacement
        }
        return [result[0], result[result.count - 1]]
    }

    /// Distance from a point to a finite line segment.
    private func distanceFromPoint(_ p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared <= .ulpOfOne {
            return hypot(p.x - a.x, p.y - a.y)
        }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        let projection = CGPoint(x: a.x + t * dx, y: a.y + t * dy)
        return hypot(p.x - projection.x, p.y - projection.y)
    }
}
