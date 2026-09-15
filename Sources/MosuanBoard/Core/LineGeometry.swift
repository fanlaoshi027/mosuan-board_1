import CoreGraphics
import Foundation

/// Geometry helpers for structured line objects and the smart-line gesture.
/// This file is renderer-independent so the same math can later be reused by
/// the macOS, Windows, and tablet input layers.
enum LineGeometry {
    static func endpoints(from points: [InkPoint]) -> (CGPoint, CGPoint)? {
        guard let first = points.first, let last = points.last, points.count >= 2 else { return nil }
        return (CGPoint(x: CGFloat(first.x), y: CGFloat(first.y)),
                CGPoint(x: CGFloat(last.x), y: CGFloat(last.y)))
    }

    /// Measures how far the stroke deviates from its first-to-last chord.
    static func maximumDeviation(from points: [InkPoint]) -> CGFloat {
        guard let (start, end) = endpoints(from: points) else { return .infinity }
        return points.reduce(CGFloat.zero) { maximum, point in
            max(maximum, distance(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)), to: (start, end)))
        }
    }

    /// Returns true when a freehand stroke is sufficiently line-like.
    /// `tolerance` is in canvas points, while `minimumLength` prevents tiny taps
    /// from becoming lines.
    static func isLikelyStraight(points: [InkPoint], tolerance: CGFloat = 8, minimumLength: CGFloat = 18) -> Bool {
        guard let (start, end) = endpoints(from: points) else { return false }
        let length = hypot(end.x - start.x, end.y - start.y)
        guard length >= minimumLength else { return false }
        return maximumDeviation(from: points) <= tolerance
    }

    /// Tests a point against a structured line in canvas coordinates.
    static func hitTest(point: CGPoint, start: CGPoint, end: CGPoint, tolerance: CGFloat = 10) -> Bool {
        distance(point, to: (start, end)) <= tolerance
    }

    /// Computes the nearest point on a line segment. Useful for endpoint
    /// dragging and snapping without changing the original object geometry.
    static func nearestPoint(onSegmentTo point: CGPoint, start: CGPoint, end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let denominator = dx * dx + dy * dy
        guard denominator > 0.000001 else { return start }
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / denominator))
        return CGPoint(x: start.x + t * dx, y: start.y + t * dy)
    }

    private static func distance(_ point: CGPoint, to segment: (CGPoint, CGPoint)) -> CGFloat {
        let nearest = nearestPoint(onSegmentTo: point, start: segment.0, end: segment.1)
        return hypot(point.x - nearest.x, point.y - nearest.y)
    }
}
