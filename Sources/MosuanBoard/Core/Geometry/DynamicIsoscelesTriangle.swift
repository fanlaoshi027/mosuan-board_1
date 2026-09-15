import CoreGraphics
import Foundation

/// A teaching-oriented dynamic isosceles triangle.
/// A is fixed, AB == AC is preserved, and apex angle / equal-leg length are parameters.
struct DynamicIsoscelesTriangle: Codable, Equatable, Identifiable {
    let id: UUID
    var triangle: ParameterizedTriangle
    var angleMinimum: CGFloat
    var angleMaximum: CGFloat
    var angleStep: CGFloat
    var legMinimum: CGFloat
    var legMaximum: CGFloat
    var legStep: CGFloat
    var animationSpeed: CGFloat
    var animationLoop: GeometryParameterLoop
    var animationDirection: CGFloat

    init(
        id: UUID = UUID(),
        anchor: CGPoint,
        legLength: CGFloat = 150,
        apexAngleDegrees: CGFloat = 60,
        minimum: CGFloat = 30,
        maximum: CGFloat = 150,
        step: CGFloat = 1,
        legMinimum: CGFloat = 50,
        legMaximum: CGFloat = 300,
        legStep: CGFloat = 1,
        animationSpeed: CGFloat = 1,
        animationLoop: GeometryParameterLoop = .pingPong
    ) {
        self.id = id
        self.triangle = ParameterizedTriangle(
            kind: .isosceles,
            anchor: anchor,
            legLength: max(1, legLength),
            apexAngleDegrees: apexAngleDegrees,
            lockedBaseLength: false,
            lockedLegLength: false,
            lockedApexAngle: false,
            anchorPointName: "A"
        )
        self.angleMinimum = min(minimum, maximum)
        self.angleMaximum = max(minimum, maximum)
        self.angleStep = max(0.0001, abs(step))
        self.legMinimum = min(legMinimum, legMaximum)
        self.legMaximum = max(legMinimum, legMaximum)
        self.legStep = max(0.0001, abs(legStep))
        self.animationSpeed = max(0.01, animationSpeed)
        self.animationLoop = animationLoop
        self.animationDirection = 1
        setAngle(apexAngleDegrees)
        setLegLength(legLength)
    }

    var anchor: CGPoint { triangle.anchor }
    var legLength: CGFloat { triangle.legLength }
    var apexAngleDegrees: CGFloat { triangle.apexAngleDegrees }
    var baseLength: CGFloat { triangle.baseLength }
    var vertices: [CGPoint] { triangle.vertices() }

    func angleControlPoint(radius: CGFloat = 58) -> CGPoint {
        let r = max(8, radius)
        let c = cos(triangle.rotation)
        let s = sin(triangle.rotation)
        return CGPoint(x: triangle.anchor.x - r * s, y: triangle.anchor.y + r * c)
    }

    mutating func setAngle(_ degrees: CGFloat) {
        let clamped = max(angleMinimum, min(angleMaximum, degrees))
        let snapped = angleMinimum + ((clamped - angleMinimum) / angleStep).rounded() * angleStep
        triangle.setApexAngle(max(angleMinimum, min(angleMaximum, snapped)))
    }

    mutating func setAngleFromControlPoint(_ point: CGPoint) {
        let dx = point.x - triangle.anchor.x
        let dy = point.y - triangle.anchor.y
        let c = cos(triangle.rotation)
        let s = sin(triangle.rotation)
        let localX = dx * c + dy * s
        let localY = -dx * s + dy * c
        guard hypot(localX, localY) > 0.001 else { return }
        let halfAngle = atan2(abs(localX), max(0.001, localY))
        setAngle(2 * halfAngle * 180 / .pi)
    }

    mutating func setLegLength(_ length: CGFloat) {
        let clamped = max(legMinimum, min(legMaximum, length))
        let snapped = legMinimum + ((clamped - legMinimum) / legStep).rounded() * legStep
        triangle.setLegLength(max(legMinimum, min(legMaximum, snapped)))
    }

    mutating func setRotation(_ radians: CGFloat) { triangle.setRotation(radians) }

    mutating func advanceAnimation(deltaTime: CGFloat) {
        let delta = animationSpeed * max(0, deltaTime) * angleStep * animationDirection
        let next = apexAngleDegrees + delta
        switch animationLoop {
        case .pingPong:
            if next >= angleMaximum { setAngle(angleMaximum); animationDirection = -1 }
            else if next <= angleMinimum { setAngle(angleMinimum); animationDirection = 1 }
            else { setAngle(next) }
        case .restart:
            if next >= angleMaximum { setAngle(angleMinimum) } else { setAngle(next) }
        }
    }
}

extension DynamicIsoscelesTriangle {
    func graphicObject(style: GraphicObject.Style = GraphicObject.Style()) -> GraphicObject {
        GraphicObject(id: id, kind: .parameterizedTriangle, style: style, geometry: GraphicObject.Geometry(points: vertices), triangleModel: triangle)
    }
}
