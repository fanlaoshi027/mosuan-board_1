import CoreGraphics
import Foundation

enum TriangleParameter: Equatable {
    case baseLength
    case legLength
    case apexAngle
}

/// Shared geometry interaction logic. Platform layers only provide input coordinates.
enum GeometryInteractionEngine {
    static func hitTestPoint(in model: GeometryModel, at position: CGPoint, radius: CGFloat = 14) -> UUID? {
        let radiusSquared = radius * radius
        return model.points.min { lhs, rhs in
            distanceSquared(lhs.position, position) < distanceSquared(rhs.position, position)
        }.flatMap { point in
            distanceSquared(point.position, position) <= radiusSquared ? point.id : nil
        }
    }

    /// Returns the closest line whose rendered segment is within `tolerance`.
    static func hitTestLine(in model: GeometryModel, at position: CGPoint, tolerance: CGFloat = 14) -> UUID? {
        var bestID: UUID?
        var bestDistance = tolerance
        for line in model.lines {
            guard let start = model.points.first(where: { $0.id == line.startPointID }),
                  let end = model.points.first(where: { $0.id == line.endPointID }) else { continue }
            let distance = distanceToLine(position, start: start.position, end: end.position, kind: line.kind)
            if distance <= bestDistance { bestDistance = distance; bestID = line.id }
        }
        return bestID
    }

    /// Attaches an existing point to a line/segment and immediately resolves it.
    @discardableResult
    static func attachPointToLine(_ model: inout GeometryModel, pointID: UUID, lineID: UUID, segmentOnly: Bool = false) -> Bool {
        guard model.points.contains(where: { $0.id == pointID }),
              let line = model.lines.first(where: { $0.id == lineID }),
              line.startPointID != pointID, line.endPointID != pointID else { return false }
        model.constraints.removeAll { constraint in
            switch constraint {
            case let .pointOnLine(id, _), let .pointOnSegment(id, _): return id == pointID
            default: return false
            }
        }
        if segmentOnly || line.kind == .segment {
            model.constraints.append(.pointOnSegment(pointID: pointID, lineID: lineID))
        } else {
            model.constraints.append(.pointOnLine(pointID: pointID, lineID: lineID))
        }
        GeometryConstraintSolver.apply(&model)
        return true
    }

    @discardableResult
    static func detachPointFromLine(_ model: inout GeometryModel, pointID: UUID) -> Bool {
        let oldCount = model.constraints.count
        model.constraints.removeAll { constraint in
            switch constraint {
            case let .pointOnLine(id, _), let .pointOnSegment(id, _): return id == pointID
            default: return false
            }
        }
        guard model.constraints.count != oldCount else { return false }
        GeometryConstraintSolver.apply(&model)
        return true
    }

    /// Moves a point and then resolves all dependent constraints. A point constrained
    /// to a line is projected back onto that line by the solver.
    @discardableResult
    static func dragPoint(_ model: inout GeometryModel, pointID: UUID, to position: CGPoint) -> Bool {
        guard let index = model.points.firstIndex(where: { $0.id == pointID }), !model.points[index].isFixed else { return false }
        if model.constraints.contains(where: { constraint in
            if case let .pointBinding(_, follower, _) = constraint { return follower == pointID }
            return false
        }) { return false }
        model.points[index].position = position
        GeometryConstraintSolver.apply(&model)
        return true
    }

    @discardableResult
    static func dragTriangle(_ triangle: inout ParameterizedTriangle, vertexIndex: Int, to position: CGPoint) -> Bool {
        switch vertexIndex {
        case 0:
            triangle.anchor = position
            return true
        case 1, 2:
            let dx = position.x - triangle.anchor.x
            let dy = position.y - triangle.anchor.y
            let distance = max(1, hypot(dx, dy))
            let angle = atan2(dy, dx)
            guard triangle.kind == .isosceles else { return false }
            triangle.setLegLength(distance)
            let halfApex = triangle.apexAngleDegrees * CGFloat.pi / 360
            let targetDirection = vertexIndex == 1 ? angle + halfApex : angle - halfApex
            triangle.setRotation(targetDirection - CGFloat.pi / 2)
            return true
        default:
            return false
        }
    }

    static func setTriangleParameter(_ triangle: inout ParameterizedTriangle, parameter: TriangleParameter, value: CGFloat) {
        switch parameter {
        case .baseLength: triangle.setBaseLength(value)
        case .legLength: triangle.setLegLength(value)
        case .apexAngle: triangle.setApexAngle(value)
        }
    }

    static func applyConstraints(_ model: inout GeometryModel) { GeometryConstraintSolver.apply(&model) }

    private static func distanceSquared(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x; let dy = a.y - b.y; return dx * dx + dy * dy
    }

    private static func distanceToLine(_ point: CGPoint, start: CGPoint, end: CGPoint, kind: GeometryLine.Kind) -> CGFloat {
        let dx = end.x - start.x; let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0.000001 else { return hypot(point.x - start.x, point.y - start.y) }
        var t = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
        switch kind { case .segment: t = max(0, min(1, t)); case .ray: t = max(0, t); case .line: break }
        let closest = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return hypot(point.x - closest.x, point.y - closest.y)
    }
}
