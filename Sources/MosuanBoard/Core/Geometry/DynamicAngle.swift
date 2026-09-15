import CoreGraphics
import Foundation

/// First-class dynamic angle: two rays share a vertex and one ray rotates.
struct DynamicAngle: Codable, Equatable, Identifiable {
    let id: UUID
    var model: GeometryModel
    let vertexPointID: UUID
    let startPointID: UUID
    let endPointID: UUID
    let angleID: UUID
    let parameterID: UUID

    var angleDegrees: CGFloat? {
        guard let a = model.angles.first(where: { $0.id == angleID }) else { return nil }
        return GeometryAngleCalculator.value(in: model, annotation: a)?.degrees
    }

    var parameter: GeometryParameter? { model.parameter(id: parameterID) }

    @discardableResult
    mutating func setAngle(_ degrees: CGFloat) -> Bool {
        model.setParameterAndResolve(parameterID, value: degrees)
    }

    @discardableResult
    mutating func setRange(minimum: CGFloat, maximum: CGFloat, step: CGFloat = 1) -> Bool {
        guard let i = model.parameters.firstIndex(where: { $0.id == parameterID }) else { return false }
        model.parameters[i].setRange(minimum: minimum, maximum: maximum, step: step)
        GeometryConstraintSolver.apply(&model)
        return true
    }

    @discardableResult
    mutating func setAnimationLoop(_ loop: GeometryParameterLoop) -> Bool {
        guard let i = model.parameters.firstIndex(where: { $0.id == parameterID }) else { return false }
        model.parameters[i].animationLoop = loop
        return true
    }

    @discardableResult
    mutating func setAnimationSpeed(_ speed: CGFloat) -> Bool {
        guard let i = model.parameters.firstIndex(where: { $0.id == parameterID }) else { return false }
        model.parameters[i].animationSpeed = max(0.01, speed)
        return true
    }

    static func make(vertex: CGPoint, startLength: CGFloat = 180, endLength: CGFloat = 180, angleDegrees: CGFloat = 45, minimum: CGFloat = 10, maximum: CGFloat = 170, step: CGFloat = 1, name: String = "α") -> DynamicAngle {
        let o = GeometryPoint(name: "O", position: vertex, isFixed: true)
        let a = GeometryPoint(name: "A", position: CGPoint(x: vertex.x + startLength, y: vertex.y), isFixed: true)
        let r = angleDegrees * .pi / 180
        let b = GeometryPoint(name: "B", position: CGPoint(x: vertex.x + endLength * cos(r), y: vertex.y + endLength * sin(r)))
        let l1 = GeometryLine(startPointID: o.id, endPointID: a.id, kind: .ray)
        let l2 = GeometryLine(startPointID: o.id, endPointID: b.id, kind: .ray)
        let p = GeometryParameter(name: name, value: angleDegrees, minimum: minimum, maximum: maximum, step: step)
        let angle = GeometryAngleAnnotation(vertexID: o.id, startPointID: a.id, endPointID: b.id, mode: .nameAndDegrees, name: name, angleReference: .parameter(p.id), labelOffset: CGPoint(x: 0, y: -12), radius: min(startLength, endLength) * 0.32, autoAvoid: true)
        var model = GeometryModel(points: [o, a, b], lines: [l1, l2], angles: [angle], parameters: [p])
        GeometryConstraintSolver.apply(&model)
        return DynamicAngle(id: UUID(), model: model, vertexPointID: o.id, startPointID: a.id, endPointID: b.id, angleID: angle.id, parameterID: p.id)
    }
}

extension DynamicAngle {
    /// Bridges the structured geometry model into the editable board object layer.
    func graphicObject(style: GraphicObject.Style = GraphicObject.Style()) -> GraphicObject {
        GraphicObject(
            id: id,
            kind: .dynamicAngle,
            style: style,
            geometry: GraphicObject.Geometry(points: model.points.map(\.position)),
            geometryModel: model,
            dynamicAngleModel: self
        )
    }
}
