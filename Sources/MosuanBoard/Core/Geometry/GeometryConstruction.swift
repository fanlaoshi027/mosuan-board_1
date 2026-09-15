import CoreGraphics
import Foundation

/// Ratio-based construction helpers used by the geometry tools.
enum GeometryConstruction {
    static func pointOnSegment(model: inout GeometryModel, startPointID: UUID, endPointID: UUID, ratio: CGFloat, name: String? = nil) -> UUID? {
        guard let start = model.points.first(where: { $0.id == startPointID }), let end = model.points.first(where: { $0.id == endPointID }), ratio.isFinite else { return nil }
        let pointID = UUID()
        model.points.append(GeometryPoint(id: pointID, name: name, position: interpolate(start.position, end.position, ratio: ratio)))
        model.constraints.append(.pointAtSegmentRatio(pointID: pointID, startPointID: startPointID, endPointID: endPointID, ratio: ratio))
        GeometryConstraintSolver.apply(&model)
        return pointID
    }

    static func pointOnAngle(model: inout GeometryModel, vertexID: UUID, startPointID: UUID, endPointID: UUID, ratio: CGFloat, name: String? = nil, length: CGFloat = 80) -> UUID? {
        guard let vertex = model.points.first(where: { $0.id == vertexID }), let start = model.points.first(where: { $0.id == startPointID }), let end = model.points.first(where: { $0.id == endPointID }), ratio.isFinite, length > 0 else { return nil }
        let a = CGPoint(x: start.position.x - vertex.position.x, y: start.position.y - vertex.position.y)
        let b = CGPoint(x: end.position.x - vertex.position.x, y: end.position.y - vertex.position.y)
        let la = hypot(a.x, a.y), lb = hypot(b.x, b.y)
        guard la > 0.0001, lb > 0.0001 else { return nil }
        let startAngle = atan2(a.y, a.x)
        let included = acos(max(-1, min(1, (a.x * b.x + a.y * b.y) / (la * lb))))
        let signed: CGFloat = (a.x * b.y - a.y * b.x) >= 0 ? 1 : -1
        let targetAngle = startAngle + signed * included * ratio
        let pointID = UUID()
        model.points.append(GeometryPoint(id: pointID, name: name, position: CGPoint(x: vertex.position.x + length * cos(targetAngle), y: vertex.position.y + length * sin(targetAngle))))
        model.constraints.append(.pointAtAngleRatio(pointID: pointID, vertexID: vertexID, startPointID: startPointID, endPointID: endPointID, ratio: ratio, length: length))
        GeometryConstraintSolver.apply(&model)
        return pointID
    }

    /// Constrains an existing point to a line/segment and resolves it immediately.
    static func attachPointToLine(model: inout GeometryModel, pointID: UUID, lineID: UUID, segmentOnly: Bool = false) -> Bool {
        GeometryInteractionEngine.attachPointToLine(&model, pointID: pointID, lineID: lineID, segmentOnly: segmentOnly)
    }

    /// Creates a new dependent point at the nearest position on a line.
    static func createPointOnLine(model: inout GeometryModel, lineID: UUID, position: CGPoint, name: String? = nil, segmentOnly: Bool = false) -> UUID? {
        guard let line = model.lines.first(where: { $0.id == lineID }),
              let a = model.points.first(where: { $0.id == line.startPointID }),
              let b = model.points.first(where: { $0.id == line.endPointID }) else { return nil }
        let projected = project(position, onto: a.position, b.position, kind: line.kind, segmentOnly: segmentOnly)
        let pointID = UUID()
        model.points.append(GeometryPoint(id: pointID, name: name, position: projected))
        guard GeometryInteractionEngine.attachPointToLine(&model, pointID: pointID, lineID: lineID, segmentOnly: segmentOnly) else { return nil }
        return pointID
    }

    /// Creates a point at the intersection of two non-parallel lines.
    /// The point is added to the same geometry model, so future constraint solving can
    /// keep it attached to both source lines.
    static func createIntersectionPoint(model: inout GeometryModel, firstLineID: UUID, secondLineID: UUID, name: String? = nil, segmentOnly: Bool = false) -> UUID? {
        guard firstLineID != secondLineID,
              let first = model.lines.first(where: { $0.id == firstLineID }),
              let second = model.lines.first(where: { $0.id == secondLineID }),
              let a = point(in: model, id: first.startPointID),
              let b = point(in: model, id: first.endPointID),
              let c = point(in: model, id: second.startPointID),
              let d = point(in: model, id: second.endPointID),
              let intersection = intersection(of: a, b, c, d, firstKind: first.kind, secondKind: second.kind, segmentOnly: segmentOnly) else { return nil }
        let pointID = UUID()
        model.points.append(GeometryPoint(id: pointID, name: name, position: intersection))
        model.constraints.append(.pointOnLine(pointID: pointID, lineID: firstLineID))
        model.constraints.append(.pointOnLine(pointID: pointID, lineID: secondLineID))
        GeometryConstraintSolver.apply(&model)
        return pointID
    }

    private static func point(in model: GeometryModel, id: UUID) -> CGPoint? {
        model.points.first(where: { $0.id == id })?.position
    }

    private static func intersection(of a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint, firstKind: GeometryLine.Kind, secondKind: GeometryLine.Kind, segmentOnly: Bool) -> CGPoint? {
        let r = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let s = CGPoint(x: d.x - c.x, y: d.y - c.y)
        let denominator = r.x * s.y - r.y * s.x
        guard abs(denominator) > 0.000001 else { return nil }
        let ca = CGPoint(x: c.x - a.x, y: c.y - a.y)
        let t = (ca.x * s.y - ca.y * s.x) / denominator
        let u = (ca.x * r.y - ca.y * r.x) / denominator
        let firstAllows: Bool = segmentOnly || firstKind == .segment ? t >= -0.000001 && t <= 1.000001 : firstKind != .ray || t >= -0.000001
        let secondAllows: Bool = segmentOnly || secondKind == .segment ? u >= -0.000001 && u <= 1.000001 : secondKind != .ray || u >= -0.000001
        guard firstAllows && secondAllows else { return nil }
        return CGPoint(x: a.x + t * r.x, y: a.y + t * r.y)
    }

    private static func interpolate(_ a: CGPoint, _ b: CGPoint, ratio: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * ratio, y: a.y + (b.y - a.y) * ratio)
    }

    private static func project(_ p: CGPoint, onto a: CGPoint, _ b: CGPoint, kind: GeometryLine.Kind, segmentOnly: Bool) -> CGPoint {
        let dx = b.x - a.x, dy = b.y - a.y
        let q = dx * dx + dy * dy
        guard q > 0.000001 else { return a }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / q
        if segmentOnly || kind == .segment { t = max(0, min(1, t)) }
        if kind == .ray { t = max(0, t) }
        return CGPoint(x: a.x + t * dx, y: a.y + t * dy)
    }
}
