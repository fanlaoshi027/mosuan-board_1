import CoreGraphics
import Foundation

enum GeometryConstraintSolver {
    static func apply(_ model: inout GeometryModel) {
        applyParameterizedLengths(&model)
        applyParameterizedAngles(&model)

        for constraint in model.constraints {
            switch constraint {
            case let .fixedPoint(pointID, position):
                set(&model, pointID: pointID, position: position)
            case let .pointBinding(master, follower, offset):
                guard let masterPoint = model.points.first(where: { $0.id == master }) else { continue }
                set(&model, pointID: follower, position: CGPoint(x: masterPoint.position.x + offset.x, y: masterPoint.position.y + offset.y))
            case let .pointOnLine(pointID, lineID):
                project(&model, pointID: pointID, lineID: lineID, lowerBound: nil, upperBound: nil)
            case let .pointOnSegment(pointID, lineID):
                project(&model, pointID: pointID, lineID: lineID, lowerBound: 0, upperBound: 1)
            case let .pointAtSegmentRatio(pointID, startPointID, endPointID, ratio):
                setSegmentRatio(&model, pointID: pointID, startPointID: startPointID, endPointID: endPointID, ratio: ratio)
            case let .pointAtAngleRatio(pointID, vertexID, startPointID, endPointID, ratio, length):
                setAngleRatio(&model, pointID: pointID, vertexID: vertexID, startPointID: startPointID, endPointID: endPointID, ratio: ratio, length: length)
            case let .pointOnCircle(pointID, circleID):
                _ = pointID; _ = circleID
            case let .fixedLength(segmentID, length):
                setLength(&model, lineID: segmentID, targetLength: max(0.001, length))
            case let .equalLength(first, second):
                if let length = lineLength(model, lineID: first) { setLength(&model, lineID: second, targetLength: length) }
            case let .lengthRatio(first, second, multiplier):
                guard let firstLength = lineLength(model, lineID: first) else { continue }
                setLength(&model, lineID: second, targetLength: firstLength / max(0.0001, multiplier))
            case let .fixedAngle(angleID, degrees):
                setAngle(&model, angleID: angleID, targetDegrees: degrees)
            case let .equalAngle(first, second):
                if let value = angleValue(in: model, id: first) { setAngle(&model, angleID: second, targetDegrees: value) }
            case let .angleRatio(first, second, multiplier):
                if let value = angleValue(in: model, id: first) { setAngle(&model, angleID: second, targetDegrees: value / max(0.0001, multiplier)) }
            case let .rotationAround(pointID, objectID):
                _ = pointID; _ = objectID
            case let .parallel(first, second):
                setLineDirection(&model, referenceLineID: first, constrainedLineID: second, perpendicular: false)
            case let .perpendicular(first, second):
                setLineDirection(&model, referenceLineID: first, constrainedLineID: second, perpendicular: true)
            }
        }
    }

    private static func applyParameterizedLengths(_ model: inout GeometryModel) {
        for line in model.lines where line.kind == .segment {
            guard let reference = line.lengthReference, let target = reference.resolved(using: model.parameters) else { continue }
            setLength(&model, lineID: line.id, targetLength: target)
        }
    }

    private static func applyParameterizedAngles(_ model: inout GeometryModel) {
        for annotation in model.angles {
            guard let target = GeometryAngleCalculator.targetDegrees(in: model, annotation: annotation) else { continue }
            setAngle(&model, angleID: annotation.id, targetDegrees: target)
        }
    }

    private static func set(_ model: inout GeometryModel, pointID: UUID, position: CGPoint) {
        guard let index = model.points.firstIndex(where: { $0.id == pointID }) else { return }
        if !model.points[index].isFixed { model.points[index].position = position }
    }

    private static func project(_ model: inout GeometryModel, pointID: UUID, lineID: UUID, lowerBound: CGFloat?, upperBound: CGFloat?) {
        guard let pointIndex = model.points.firstIndex(where: { $0.id == pointID }),
              !model.points[pointIndex].isFixed,
              let line = model.lines.first(where: { $0.id == lineID }),
              let start = model.points.first(where: { $0.id == line.startPointID }),
              let end = model.points.first(where: { $0.id == line.endPointID }) else { return }
        let dx = end.position.x - start.position.x
        let dy = end.position.y - start.position.y
        let denominator = dx * dx + dy * dy
        guard denominator > 0 else { return }
        let p = model.points[pointIndex].position
        var t = ((p.x - start.position.x) * dx + (p.y - start.position.y) * dy) / denominator
        if let lowerBound { t = max(lowerBound, t) }
        if let upperBound { t = min(upperBound, t) }
        model.points[pointIndex].position = CGPoint(x: start.position.x + t * dx, y: start.position.y + t * dy)
    }

    private static func setSegmentRatio(_ model: inout GeometryModel, pointID: UUID, startPointID: UUID, endPointID: UUID, ratio: CGFloat) {
        guard let pointIndex = model.points.firstIndex(where: { $0.id == pointID }),
              !model.points[pointIndex].isFixed,
              let start = model.points.first(where: { $0.id == startPointID }),
              let end = model.points.first(where: { $0.id == endPointID }) else { return }
        model.points[pointIndex].position = CGPoint(
            x: start.position.x + (end.position.x - start.position.x) * ratio,
            y: start.position.y + (end.position.y - start.position.y) * ratio
        )
    }

    private static func setAngleRatio(_ model: inout GeometryModel, pointID: UUID, vertexID: UUID, startPointID: UUID, endPointID: UUID, ratio: CGFloat, length: CGFloat) {
        guard let pointIndex = model.points.firstIndex(where: { $0.id == pointID }),
              !model.points[pointIndex].isFixed,
              let vertex = model.points.first(where: { $0.id == vertexID }),
              let start = model.points.first(where: { $0.id == startPointID }),
              let end = model.points.first(where: { $0.id == endPointID }) else { return }
        let a = CGPoint(x: start.position.x - vertex.position.x, y: start.position.y - vertex.position.y)
        let b = CGPoint(x: end.position.x - vertex.position.x, y: end.position.y - vertex.position.y)
        let la = hypot(a.x, a.y)
        let lb = hypot(b.x, b.y)
        guard la > 0.0001, lb > 0.0001, length > 0 else { return }
        let included = acos(max(-1, min(1, (a.x * b.x + a.y * b.y) / (la * lb))))
        let cross = a.x * b.y - a.y * b.x
        let signed = cross >= 0 ? 1 : -1
        let angle = atan2(a.y, a.x) + CGFloat(signed) * included * ratio
        model.points[pointIndex].position = CGPoint(x: vertex.position.x + length * cos(angle), y: vertex.position.y + length * sin(angle))
    }

    private static func lineLength(_ model: GeometryModel, lineID: UUID) -> CGFloat? {
        guard let line = model.lines.first(where: { $0.id == lineID }),
              let a = model.points.first(where: { $0.id == line.startPointID }),
              let b = model.points.first(where: { $0.id == line.endPointID }) else { return nil }
        return hypot(b.position.x - a.position.x, b.position.y - a.position.y)
    }

    private static func setLength(_ model: inout GeometryModel, lineID: UUID, targetLength: CGFloat) {
        guard let line = model.lines.first(where: { $0.id == lineID }),
              let startIndex = model.points.firstIndex(where: { $0.id == line.startPointID }),
              let endIndex = model.points.firstIndex(where: { $0.id == line.endPointID }) else { return }
        let start = model.points[startIndex].position
        let end = model.points[endIndex].position
        let dx = end.x - start.x
        let dy = end.y - start.y
        let current = hypot(dx, dy)
        let angle = current > 0.0001 ? atan2(dy, dx) : 0
        let target = max(0.001, targetLength)
        if !model.points[endIndex].isFixed {
            model.points[endIndex].position = CGPoint(x: start.x + target * cos(angle), y: start.y + target * sin(angle))
        } else if !model.points[startIndex].isFixed {
            model.points[startIndex].position = CGPoint(x: end.x - target * cos(angle), y: end.y - target * sin(angle))
        }
    }

    private static func setLineDirection(_ model: inout GeometryModel, referenceLineID: UUID, constrainedLineID: UUID, perpendicular: Bool) {
        guard referenceLineID != constrainedLineID,
              let reference = model.lines.first(where: { $0.id == referenceLineID }),
              let constrained = model.lines.first(where: { $0.id == constrainedLineID }),
              let referenceStart = model.points.first(where: { $0.id == reference.startPointID }),
              let referenceEnd = model.points.first(where: { $0.id == reference.endPointID }),
              let constrainedStartIndex = model.points.firstIndex(where: { $0.id == constrained.startPointID }),
              let constrainedEndIndex = model.points.firstIndex(where: { $0.id == constrained.endPointID }) else { return }

        let referenceDX = referenceEnd.position.x - referenceStart.position.x
        let referenceDY = referenceEnd.position.y - referenceStart.position.y
        let referenceLength = hypot(referenceDX, referenceDY)
        guard referenceLength > 0.0001 else { return }

        let constrainedStart = model.points[constrainedStartIndex].position
        let constrainedEnd = model.points[constrainedEndIndex].position
        let currentDX = constrainedEnd.x - constrainedStart.x
        let currentDY = constrainedEnd.y - constrainedStart.y
        let currentLength = hypot(currentDX, currentDY)
        guard currentLength > 0.0001 else { return }

        var ux = referenceDX / referenceLength
        var uy = referenceDY / referenceLength
        if perpendicular {
            let rotatedX = -uy
            let rotatedY = ux
            ux = rotatedX
            uy = rotatedY
        }

        if !model.points[constrainedEndIndex].isFixed {
            model.points[constrainedEndIndex].position = CGPoint(
                x: constrainedStart.x + currentLength * ux,
                y: constrainedStart.y + currentLength * uy
            )
        } else if !model.points[constrainedStartIndex].isFixed {
            model.points[constrainedStartIndex].position = CGPoint(
                x: constrainedEnd.x - currentLength * ux,
                y: constrainedEnd.y - currentLength * uy
            )
        }
    }

    private static func angleValue(in model: GeometryModel, id: UUID) -> CGFloat? {
        guard let annotation = model.angles.first(where: { $0.id == id }) else { return nil }
        return GeometryAngleCalculator.value(in: model, annotation: annotation)?.degrees
    }

    private static func setAngle(_ model: inout GeometryModel, angleID: UUID, targetDegrees: CGFloat) {
        guard let annotation = model.angles.first(where: { $0.id == angleID }),
              let vertex = model.points.first(where: { $0.id == annotation.vertexID }),
              let start = model.points.first(where: { $0.id == annotation.startPointID }),
              let endIndex = model.points.firstIndex(where: { $0.id == annotation.endPointID }),
              !model.points[endIndex].isFixed else { return }
        let startVector = CGPoint(x: start.position.x - vertex.position.x, y: start.position.y - vertex.position.y)
        let endVector = CGPoint(x: model.points[endIndex].position.x - vertex.position.x, y: model.points[endIndex].position.y - vertex.position.y)
        let startLength = hypot(startVector.x, startVector.y)
        let radius = max(0.001, hypot(endVector.x, endVector.y))
        guard startLength > 0.0001 else { return }
        let startAngle = atan2(startVector.y, startVector.x)
        let direction = max(0.001, min(179.999, targetDegrees)) * .pi / 180
        let currentCross = startVector.x * endVector.y - startVector.y * endVector.x
        let signedDirection: CGFloat = currentCross >= 0 ? 1 : -1
        let angle = startAngle + signedDirection * direction
        model.points[endIndex].position = CGPoint(x: vertex.position.x + radius * cos(angle), y: vertex.position.y + radius * sin(angle))
    }
}
