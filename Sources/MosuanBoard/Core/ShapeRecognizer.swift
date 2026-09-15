import CoreGraphics
import Foundation

/// First-version recognition for shapes drawn freehand with the pen.
/// Recognition is intentionally conservative: only a closed polygon/triangle
/// and a circle are promoted to structured objects.
struct RecognizedShape {
    enum Kind: Equatable {
        case polygon
        case circle
    }

    let kind: Kind
    let points: [CGPoint]
    let bounds: CGRect
}

struct ShapeRecognizer {
    var closureTolerance: CGFloat = 28
    var circleErrorRatio: CGFloat = 0.18
    var polygonCornerAngle: CGFloat = 0.70

    func recognize(_ rawPoints: [CGPoint]) -> RecognizedShape? {
        guard rawPoints.count >= 12,
              let first = rawPoints.first,
              let last = rawPoints.last else { return nil }

        let bounds = rawPoints.reduce(CGRect.null) { partial, point in
            partial.union(CGRect(origin: point, size: .zero))
        }
        let size = max(bounds.width, bounds.height)
        guard size >= 24 else { return nil }
        guard hypot(first.x - last.x, first.y - last.y) <= max(closureTolerance, size * 0.10) else { return nil }

        if isCircle(rawPoints, bounds: bounds) {
            return RecognizedShape(kind: .circle, points: [], bounds: bounds)
        }

        let corners = simplifyClosedPath(rawPoints)
        guard corners.count >= 3, corners.count <= 8 else { return nil }
        return RecognizedShape(kind: .polygon, points: corners, bounds: bounds)
    }

    private func isCircle(_ points: [CGPoint], bounds: CGRect) -> Bool {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radii = points.map { hypot($0.x - center.x, $0.y - center.y) }
        guard let average = radii.reduce(0, +).isFinite ? radii.reduce(0, +) / CGFloat(radii.count) : nil,
              average > 0 else { return false }
        let meanError = radii.reduce(0) { $0 + abs($1 - average) } / CGFloat(radii.count)
        let aspect = min(bounds.width, bounds.height) / max(bounds.width, bounds.height)
        return aspect >= 0.78 && meanError / average <= circleErrorRatio
    }

    private func simplifyClosedPath(_ points: [CGPoint]) -> [CGPoint] {
        let stride = max(1, points.count / 80)
        let sampled = Array(points.enumerated().compactMap { index, point in
            index % stride == 0 ? point : nil
        })
        guard sampled.count >= 3 else { return sampled }

        var corners: [CGPoint] = []
        for i in sampled.indices {
            let prev = sampled[(i - 1 + sampled.count) % sampled.count]
            let current = sampled[i]
            let next = sampled[(i + 1) % sampled.count]
            let v1 = CGVector(dx: prev.x - current.x, dy: prev.y - current.y)
            let v2 = CGVector(dx: next.x - current.x, dy: next.y - current.y)
            let l1 = hypot(v1.dx, v1.dy)
            let l2 = hypot(v2.dx, v2.dy)
            guard l1 > 1, l2 > 1 else { continue }
            let cosine = max(-1, min(1, (v1.dx * v2.dx + v1.dy * v2.dy) / (l1 * l2)))
            let angle = acos(cosine)
            if angle < polygonCornerAngle {
                corners.append(current)
            }
        }

        if corners.count > 8 {
            corners = Array(corners.prefix(8))
        }
        return corners
    }
}
