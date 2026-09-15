import CoreGraphics
import Foundation

/// Cross-platform, input-device-independent recognition of simple one-stroke shapes.
/// The recognizer only proposes a structured object; the caller decides whether
/// the global "一笔成型" switch is enabled and whether to accept the proposal.
struct OneStrokeShapeRecognizer {
    enum Shape: Equatable {
        case line(start: CGPoint, end: CGPoint)
        case arrow(start: CGPoint, end: CGPoint)
        case rectangle(CGRect)
        case ellipse(CGRect)
        case triangle([CGPoint])
    }

    struct Result: Equatable {
        let shape: Shape
        let score: CGFloat
        var isConfident: Bool { score >= 0.72 }
    }

    struct Configuration: Equatable {
        var enabled = true
        var minimumPoints = 8
        var minimumLength: CGFloat = 24
        var closedDistanceRatio: CGFloat = 0.16
        var lineStraightness: CGFloat = 0.985
        var shapeFitTolerance: CGFloat = 0.12
    }

    var configuration = Configuration()

    func recognize(points input: [CGPoint]) -> Result? {
        guard configuration.enabled else { return nil }
        let points = simplified(input)
        guard points.count >= configuration.minimumPoints,
              let first = points.first,
              let last = points.last else { return nil }
        let length = pathLength(points)
        guard length >= configuration.minimumLength else { return nil }
        let bounds = boundingBox(points)
        guard bounds.width > 1 || bounds.height > 1 else { return nil }

        let endpointDistance = distance(first, last)
        let closed = endpointDistance <= max(bounds.width, bounds.height) * configuration.closedDistanceRatio
        if !closed { return recognizeLine(points: points, length: length) }

        if let rectangle = recognizeRectangle(points: points, bounds: bounds) { return rectangle }
        if let triangle = recognizeTriangle(points: points, bounds: bounds) { return triangle }
        if let ellipse = recognizeEllipse(points: points, bounds: bounds) { return ellipse }
        return nil
    }

    func makeGraphicObject(from result: Result, style: GraphicObject.Style) -> GraphicObject {
        switch result.shape {
        case let .line(start, end):
            return .line(from: start, to: end, style: style)
        case let .arrow(start, end):
            var object = GraphicObject.line(from: start, to: end, style: style)
            object.kind = .arrow
            object.geometry.parameters["arrowHead"] = 1
            object.geometry.parameters["arrowHeadLength"] = Double(max(style.strokeWidth * 4, 10))
            return object
        case let .rectangle(rect):
            return .rectangle(rect, style: style)
        case let .ellipse(rect):
            return .ellipse(rect, style: style)
        case let .triangle(points):
            return .polygon(points: points, style: style)
        }
    }

    private func recognizeLine(points: [CGPoint], length: CGFloat) -> Result? {
        guard let first = points.first, let last = points.last else { return nil }
        let direct = distance(first, last)
        guard direct > 0 else { return nil }
        let straightness = direct / max(length, 0.001)
        guard straightness >= configuration.lineStraightness else { return nil }
        let score = min(0.99, 0.72 + (straightness - configuration.lineStraightness) * 12)
        if looksLikeArrow(points: points, shaftStart: first, shaftEnd: last) {
            return Result(shape: .arrow(start: first, end: last), score: min(score, 0.90))
        }
        return Result(shape: .line(start: first, end: last), score: score)
    }

    private func looksLikeArrow(points: [CGPoint], shaftStart: CGPoint, shaftEnd: CGPoint) -> Bool {
        guard points.count >= 10 else { return false }
        let total = pathLength(points)
        guard total > 0 else { return false }
        let tailDistance = max(total * 0.16, 8)
        var travelled: CGFloat = 0
        var candidates: [CGPoint] = []
        for index in stride(from: points.count - 1, through: 1, by: -1) {
            travelled += distance(points[index], points[index - 1])
            candidates.append(points[index])
            if travelled >= tailDistance { break }
        }
        guard candidates.count >= 3 else { return false }
        let end = shaftEnd
        let shaftVector = CGVector(dx: end.x - shaftStart.x, dy: end.y - shaftStart.y)
        let shaftLength = hypot(shaftVector.dx, shaftVector.dy)
        guard shaftLength > 1 else { return false }
        let ux = shaftVector.dx / shaftLength
        let uy = shaftVector.dy / shaftLength
        let lateral = candidates.map { abs(($0.x - end.x) * (-uy) + ($0.y - end.y) * ux) }
        return (lateral.max() ?? 0) >= max(4, shaftLength * 0.035)
    }

    private func recognizeRectangle(points: [CGPoint], bounds: CGRect) -> Result? {
        guard bounds.width > 12, bounds.height > 12 else { return nil }
        let corners = [
            CGPoint(x: bounds.minX, y: bounds.minY),
            CGPoint(x: bounds.maxX, y: bounds.minY),
            CGPoint(x: bounds.maxX, y: bounds.maxY),
            CGPoint(x: bounds.minX, y: bounds.maxY)
        ]
        let error = averageDistanceToPolyline(points, corners + [corners[0]]) / max(bounds.width, bounds.height)
        guard error <= configuration.shapeFitTolerance else { return nil }
        let aspect = min(bounds.width, bounds.height) / max(bounds.width, bounds.height)
        let score = min(0.98, 0.82 + (1 - min(error / configuration.shapeFitTolerance, 1)) * 0.10 + aspect * 0.04)
        return Result(shape: .rectangle(bounds), score: score)
    }

    private func recognizeTriangle(points: [CGPoint], bounds: CGRect) -> Result? {
        guard points.count >= 3 else { return nil }
        let candidates = extremePoints(points, bounds: bounds)
        guard candidates.count == 3 else { return nil }
        let triangle = orderedPolygon(candidates)
        let error = averageDistanceToPolyline(points, triangle + [triangle[0]]) / max(bounds.width, bounds.height)
        guard error <= configuration.shapeFitTolerance else { return nil }
        return Result(shape: .triangle(triangle), score: min(0.95, 0.78 + (1 - error / configuration.shapeFitTolerance) * 0.15))
    }

    private func recognizeEllipse(points: [CGPoint], bounds: CGRect) -> Result? {
        guard bounds.width > 12, bounds.height > 12 else { return nil }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let rx = bounds.width / 2
        let ry = bounds.height / 2
        guard rx > 0, ry > 0 else { return nil }
        var error: CGFloat = 0
        for point in points {
            let nx = (point.x - center.x) / rx
            let ny = (point.y - center.y) / ry
            error += abs(hypot(nx, ny) - 1)
        }
        error /= CGFloat(points.count)
        guard error <= configuration.shapeFitTolerance else { return nil }
        return Result(shape: .ellipse(bounds), score: min(0.96, 0.80 + (1 - error / configuration.shapeFitTolerance) * 0.14))
    }

    private func simplified(_ input: [CGPoint]) -> [CGPoint] {
        guard input.count > 2 else { return input }
        var output: [CGPoint] = [input[0]]
        let minimumSpacing: CGFloat = 1.5
        for point in input.dropFirst() {
            if distance(output[output.count - 1], point) >= minimumSpacing { output.append(point) }
        }
        return output
    }

    private func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        return zip(points.dropFirst(), points).reduce(CGFloat.zero) { $0 + distance($1.0, $1.1) }
    }

    private func boundingBox(_ points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points.dropFirst() {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    private func averageDistanceToPolyline(_ points: [CGPoint], _ polyline: [CGPoint]) -> CGFloat {
        guard polyline.count >= 2 else { return .greatestFiniteMagnitude }
        var total: CGFloat = 0
        for point in points {
            var best = CGFloat.greatestFiniteMagnitude
            for i in 0..<(polyline.count - 1) { best = min(best, distance(point, polyline[i], polyline[i + 1])) }
            total += best
        }
        return total / CGFloat(max(points.count, 1))
    }

    private func distance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let denominator = dx * dx + dy * dy
        if denominator <= 0 { return distance(p, a) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / denominator))
        return distance(p, CGPoint(x: a.x + t * dx, y: a.y + t * dy))
    }

    private func extremePoints(_ points: [CGPoint], bounds: CGRect) -> [CGPoint] {
        let candidates = [
            points.min { $0.y + abs($0.x - bounds.midX) * 0.08 < $1.y + abs($1.x - bounds.midX) * 0.08 },
            points.min { $0.x < $1.x },
            points.max { $0.x < $1.x }
        ].compactMap { $0 }
        var unique: [CGPoint] = []
        for p in candidates where unique.allSatisfy({ distance($0, p) > max(bounds.width, bounds.height) * 0.12 }) { unique.append(p) }
        return unique
    }

    private func orderedPolygon(_ points: [CGPoint]) -> [CGPoint] {
        let center = CGPoint(
            x: points.reduce(0) { $0 + $1.x } / CGFloat(points.count),
            y: points.reduce(0) { $0 + $1.y } / CGFloat(points.count)
        )
        return points.sorted {
            atan2($0.y - center.y, $0.x - center.x) < atan2($1.y - center.y, $1.x - center.x)
        }
    }
}
