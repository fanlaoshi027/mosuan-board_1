import CoreGraphics
import Foundation

/// Pure vector transforms for the selection system. The renderer can apply these to
/// freehand strokes today and to GraphicObject geometry later without changing semantics.
enum SelectionActions {
    static func scale(points: [InkPoint], around center: CGPoint, x: CGFloat, y: CGFloat) -> [InkPoint] {
        points.map { p in
            InkPoint(
                x: Float(center.x + (CGFloat(p.x) - center.x) * x),
                y: Float(center.y + (CGFloat(p.y) - center.y) * y),
                pressure: p.pressure
            )
        }
    }

    static func rotate(points: [InkPoint], around center: CGPoint, radians: CGFloat) -> [InkPoint] {
        let c = cos(radians), s = sin(radians)
        return points.map { p in
            let x = CGFloat(p.x) - center.x
            let y = CGFloat(p.y) - center.y
            return InkPoint(
                x: Float(center.x + x * c - y * s),
                y: Float(center.y + x * s + y * c),
                pressure: p.pressure
            )
        }
    }

    static func reflect(points: [InkPoint], acrossVerticalAxisAt x: CGFloat) -> [InkPoint] {
        points.map { InkPoint(x: Float(2 * x - CGFloat($0.x)), y: $0.y, pressure: $0.pressure) }
    }

    static func reflect(points: [InkPoint], acrossHorizontalAxisAt y: CGFloat) -> [InkPoint] {
        points.map { InkPoint(x: $0.x, y: Float(2 * y - CGFloat($0.y)), pressure: $0.pressure) }
    }

    static func translate(points: [InkPoint], by delta: CGSize) -> [InkPoint] {
        points.map {
            InkPoint(x: Float(CGFloat($0.x) + delta.width), y: Float(CGFloat($0.y) + delta.height), pressure: $0.pressure)
        }
    }

    static func bounds(of points: [InkPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        var minX = CGFloat(first.x), maxX = minX
        var minY = CGFloat(first.y), maxY = minY
        for point in points {
            minX = min(minX, CGFloat(point.x)); maxX = max(maxX, CGFloat(point.x))
            minY = min(minY, CGFloat(point.y)); maxY = max(maxY, CGFloat(point.y))
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
