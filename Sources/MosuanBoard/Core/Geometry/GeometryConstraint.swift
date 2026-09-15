import CoreGraphics
import Foundation

enum GeometryConstraint: Codable, Equatable, Identifiable {
    case fixedPoint(pointID: UUID, position: CGPoint)
    case pointBinding(master: UUID, follower: UUID, offset: CGPoint)
    case pointOnLine(pointID: UUID, lineID: UUID)
    case pointOnSegment(pointID: UUID, lineID: UUID)
    case pointOnCircle(pointID: UUID, circleID: UUID)
    case pointAtSegmentRatio(pointID: UUID, startPointID: UUID, endPointID: UUID, ratio: CGFloat)
    case pointAtAngleRatio(pointID: UUID, vertexID: UUID, startPointID: UUID, endPointID: UUID, ratio: CGFloat, length: CGFloat)
    case fixedLength(segmentID: UUID, length: CGFloat)
    case equalLength(first: UUID, second: UUID)
    case lengthRatio(first: UUID, second: UUID, multiplier: CGFloat)
    case fixedAngle(angleID: UUID, degrees: CGFloat)
    case equalAngle(first: UUID, second: UUID)
    case angleRatio(first: UUID, second: UUID, multiplier: CGFloat)
    case rotationAround(pointID: UUID, objectID: UUID)
    case parallel(first: UUID, second: UUID)
    case perpendicular(first: UUID, second: UUID)

    var id: String {
        switch self {
        case let .fixedPoint(pointID, _): return "fixedPoint:\(pointID.uuidString)"
        case let .pointBinding(master, follower, _): return "pointBinding:\(master.uuidString):\(follower.uuidString)"
        case let .pointOnLine(pointID, lineID): return "pointOnLine:\(pointID.uuidString):\(lineID.uuidString)"
        case let .pointOnSegment(pointID, lineID): return "pointOnSegment:\(pointID.uuidString):\(lineID.uuidString)"
        case let .pointOnCircle(pointID, circleID): return "pointOnCircle:\(pointID.uuidString):\(circleID.uuidString)"
        case let .pointAtSegmentRatio(pointID, start, end, ratio): return "pointAtSegmentRatio:\(pointID.uuidString):\(start.uuidString):\(end.uuidString):\(ratio)"
        case let .pointAtAngleRatio(pointID, vertex, start, end, ratio, length): return "pointAtAngleRatio:\(pointID.uuidString):\(vertex.uuidString):\(start.uuidString):\(end.uuidString):\(ratio):\(length)"
        case let .fixedLength(segmentID, _): return "fixedLength:\(segmentID.uuidString)"
        case let .equalLength(first, second): return "equalLength:\(first.uuidString):\(second.uuidString)"
        case let .lengthRatio(first, second, multiplier): return "lengthRatio:\(first.uuidString):\(second.uuidString):\(multiplier)"
        case let .fixedAngle(angleID, _): return "fixedAngle:\(angleID.uuidString)"
        case let .equalAngle(first, second): return "equalAngle:\(first.uuidString):\(second.uuidString)"
        case let .angleRatio(first, second, multiplier): return "angleRatio:\(first.uuidString):\(second.uuidString):\(multiplier)"
        case let .rotationAround(pointID, objectID): return "rotationAround:\(pointID.uuidString):\(objectID.uuidString)"
        case let .parallel(first, second): return "parallel:\(first.uuidString):\(second.uuidString)"
        case let .perpendicular(first, second): return "perpendicular:\(first.uuidString):\(second.uuidString)"
        }
    }
}

struct GeometryPoint: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String?
    var position: CGPoint
    var isFixed: Bool
    var label: GeometryPointLabel

    init(id: UUID = UUID(), name: String? = nil, position: CGPoint, isFixed: Bool = false, label: GeometryPointLabel? = nil) {
        self.id = id
        self.name = name
        self.position = position
        self.isFixed = isFixed
        self.label = label ?? GeometryPointLabel(mode: name == nil ? .hidden : .name, text: name ?? "")
    }

    var isLabelVisible: Bool { label.mode != .hidden && !label.text.isEmpty }
    mutating func setLabelVisible(_ visible: Bool) { label.mode = visible ? .name : .hidden }
    mutating func setLabelText(_ text: String) {
        name = text.isEmpty ? nil : text
        label.text = text
        if !text.isEmpty && label.mode == .hidden { label.mode = .name }
    }
}

struct GeometryModel: Codable, Equatable, Identifiable {
    let id: UUID
    var points: [GeometryPoint]
    var lines: [GeometryLine]
    var angles: [GeometryAngleAnnotation]
    var constraints: [GeometryConstraint]
    var parameters: [GeometryParameter]
    var translations: [GeometryTranslation]
    var translationGuides: [GeometryTranslationGuide]

    init(
        id: UUID = UUID(), points: [GeometryPoint] = [], lines: [GeometryLine] = [],
        angles: [GeometryAngleAnnotation] = [], constraints: [GeometryConstraint] = [],
        parameters: [GeometryParameter] = [], translations: [GeometryTranslation] = [],
        translationGuides: [GeometryTranslationGuide] = []
    ) {
        self.id = id; self.points = points; self.lines = lines; self.angles = angles
        self.constraints = constraints; self.parameters = parameters
        self.translations = translations; self.translationGuides = translationGuides
    }

    private enum CodingKeys: String, CodingKey { case id, points, lines, angles, constraints, parameters, translations, translationGuides }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        points = try container.decode([GeometryPoint].self, forKey: .points)
        lines = try container.decodeIfPresent([GeometryLine].self, forKey: .lines) ?? []
        angles = try container.decodeIfPresent([GeometryAngleAnnotation].self, forKey: .angles) ?? []
        constraints = try container.decode([GeometryConstraint].self, forKey: .constraints)
        parameters = try container.decodeIfPresent([GeometryParameter].self, forKey: .parameters) ?? []
        translations = try container.decodeIfPresent([GeometryTranslation].self, forKey: .translations) ?? []
        translationGuides = try container.decodeIfPresent([GeometryTranslationGuide].self, forKey: .translationGuides) ?? []
    }

    mutating func setFixed(_ pointID: UUID, position: CGPoint? = nil) {
        guard let index = points.firstIndex(where: { $0.id == pointID }) else { return }
        points[index].isFixed = true
        if let position { points[index].position = position }
        constraints.removeAll { if case let .fixedPoint(id, _) = $0 { return id == pointID }; return false }
        constraints.append(.fixedPoint(pointID: pointID, position: points[index].position))
    }

    mutating func setMovable(_ pointID: UUID) {
        guard let index = points.firstIndex(where: { $0.id == pointID }) else { return }
        points[index].isFixed = false
        constraints.removeAll { if case let .fixedPoint(id, _) = $0 { return id == pointID }; return false }
    }

    mutating func bind(master: UUID, follower: UUID) {
        guard let masterPoint = points.first(where: { $0.id == master }), let followerPoint = points.first(where: { $0.id == follower }) else { return }
        let offset = CGPoint(x: followerPoint.position.x - masterPoint.position.x, y: followerPoint.position.y - masterPoint.position.y)
        constraints.removeAll { if case let .pointBinding(existingMaster, existingFollower, _) = $0 { return existingMaster == master || existingFollower == follower }; return false }
        constraints.append(.pointBinding(master: master, follower: follower, offset: offset))
    }

    mutating func addLine(from startPointID: UUID, to endPointID: UUID, kind: GeometryLine.Kind = .segment) -> UUID? {
        guard points.contains(where: { $0.id == startPointID }), points.contains(where: { $0.id == endPointID }), startPointID != endPointID else { return nil }
        let line = GeometryLine(startPointID: startPointID, endPointID: endPointID, kind: kind)
        lines.append(line); return line.id
    }

    mutating func addParameter(_ parameter: GeometryParameter) {
        parameters.removeAll { $0.id == parameter.id || $0.name == parameter.name }; parameters.append(parameter)
    }

    mutating func setParameterValue(_ parameterID: UUID, value: CGFloat) {
        guard let index = parameters.firstIndex(where: { $0.id == parameterID }) else { return }; parameters[index].setValue(value)
    }

    func parameter(id: UUID) -> GeometryParameter? { parameters.first(where: { $0.id == id }) }
}
