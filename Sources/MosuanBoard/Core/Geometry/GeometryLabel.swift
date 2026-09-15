import CoreGraphics
import Foundation

enum GeometryPointLabelMode: String, Codable, CaseIterable { case hidden, name }

struct GeometryPointLabel: Codable, Equatable {
    var mode: GeometryPointLabelMode = .name
    var text: String = "A"
    var offset: CGPoint = CGPoint(x: 10, y: -10)
    var autoAvoid: Bool = true
    var fontSize: CGFloat = 18

    init(mode: GeometryPointLabelMode = .name, text: String = "A", offset: CGPoint = CGPoint(x: 10, y: -10), autoAvoid: Bool = true, fontSize: CGFloat = 18) {
        self.mode = mode; self.text = text; self.offset = offset; self.autoAvoid = autoAvoid; self.fontSize = fontSize
    }
}

struct GeometryLabelPlacement: Equatable {
    var center: CGPoint
    var rotation: CGFloat = 0
    var bounds: CGRect
    var score: CGFloat = 0
}

enum GeometryLabelAvoidance {
    struct Obstacle { var segmentStart: CGPoint; var segmentEnd: CGPoint; var padding: CGFloat = 6 }

    static func placement(point: CGPoint, label: GeometryPointLabel, obstacles: [Obstacle], otherLabels: [CGRect] = []) -> GeometryLabelPlacement? {
        guard label.mode != .hidden, !label.text.isEmpty else { return nil }
        let estimatedWidth = max(CGFloat(label.text.count) * label.fontSize * 0.62, label.fontSize * 0.8)
        let estimatedHeight = label.fontSize * 1.25
        let size = CGSize(width: estimatedWidth, height: estimatedHeight)
        let preferred = CGPoint(x: point.x + label.offset.x, y: point.y + label.offset.y)
        guard label.autoAvoid else {
            return GeometryLabelPlacement(center: preferred, bounds: CGRect(center: preferred, size: size))
        }
        let baseAngle = atan2(label.offset.y, label.offset.x)
        let distance = max(hypot(label.offset.x, label.offset.y), label.fontSize * 0.9)
        let quarter = CGFloat.pi / 4
        let angles: [CGFloat] = [baseAngle, baseAngle + quarter, baseAngle - quarter, baseAngle + CGFloat.pi / 2, baseAngle - CGFloat.pi / 2, baseAngle + 3 * quarter, baseAngle - 3 * quarter, baseAngle + CGFloat.pi, baseAngle + CGFloat.pi / 6, baseAngle - CGFloat.pi / 6, baseAngle + 5 * CGFloat.pi / 6, baseAngle - 5 * CGFloat.pi / 6]
        var best: GeometryLabelPlacement?
        for (index, angle) in angles.enumerated() {
            let candidateCenter = CGPoint(x: point.x + cos(angle) * distance, y: point.y + sin(angle) * distance)
            let rect = CGRect(center: candidateCenter, size: size)
            let score = score(rect: rect, point: point, obstacles: obstacles, otherLabels: otherLabels) + CGFloat(index) * 0.01
            let candidate = GeometryLabelPlacement(center: candidateCenter, bounds: rect, score: score)
            if best == nil || score < best!.score { best = candidate }
        }
        return best
    }

    private static func score(rect: CGRect, point: CGPoint, obstacles: [Obstacle], otherLabels: [CGRect]) -> CGFloat {
        var score: CGFloat = rect.contains(point) ? 10_000 : 0
        for obstacle in obstacles {
            let expanded = rect.insetBy(dx: -obstacle.padding, dy: -obstacle.padding)
            if expanded.intersects(lineBounds(obstacle.segmentStart, obstacle.segmentEnd)) {
                let distance = distanceFromSegmentToRect(obstacle.segmentStart, obstacle.segmentEnd, rect)
                if distance < obstacle.padding { score += (obstacle.padding - distance + 1) * 120 }
                else { score += max(0, obstacle.padding * 2 - distance) * 10 }
            }
        }
        for other in otherLabels where rect.intersects(other.insetBy(dx: -4, dy: -4)) { score += 2_000 }
        score += hypot(rect.midX - point.x, rect.midY - point.y) * 0.02
        return score
    }

    private static func lineBounds(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    private static func distanceFromSegmentToRect(_ a: CGPoint, _ b: CGPoint, _ rect: CGRect) -> CGFloat {
        if rect.contains(a) || rect.contains(b) { return 0 }
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
        if segmentIntersectsRect(a, b, rect) { return 0 }
        return corners.map { distanceFromPointToSegment($0, a, b) }.min() ?? .greatestFiniteMagnitude
    }

    private static func segmentIntersectsRect(_ a: CGPoint, _ b: CGPoint, _ rect: CGRect) -> Bool {
        if rect.contains(a) || rect.contains(b) { return true }
        let edges = [(CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY)), (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY)), (CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)), (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.minY))]
        return edges.contains { segmentsIntersect(a, b, $0.0, $0.1) }
    }

    private static func segmentsIntersect(_ p1: CGPoint, _ p2: CGPoint, _ q1: CGPoint, _ q2: CGPoint) -> Bool {
        func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat { (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) }
        let d1 = cross(p1, p2, q1), d2 = cross(p1, p2, q2), d3 = cross(q1, q2, p1), d4 = cross(q1, q2, p2)
        return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))
    }

    private static func distanceFromPointToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y, lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        let projection = CGPoint(x: a.x + t * dx, y: a.y + t * dy)
        return hypot(p.x - projection.x, p.y - projection.y)
    }
}

private extension CGRect {
    init(center: CGPoint, size: CGSize) { self.init(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height) }
}
