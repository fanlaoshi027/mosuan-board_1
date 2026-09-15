import CoreGraphics
import Foundation

/// How an angle is presented to a teacher/student.
enum GeometryAngleLabelMode: String, Codable, CaseIterable {
    case hidden
    case degrees
    case name
    case nameAndDegrees
}

/// A dynamic angle annotation. The displayed value is always calculated from
/// the current positions of the three points; it is never stored as a fixed
/// drawing value.
struct GeometryAngleAnnotation: Codable, Equatable, Identifiable {
    let id: UUID
    var vertexID: UUID
    var startPointID: UUID
    var endPointID: UUID
    var mode: GeometryAngleLabelMode
    var name: String
    /// Optional fixed/shared parameter target for driving the end ray.
    var angleReference: GeometryAngleReference?
    var labelOffset: CGPoint
    var radius: CGFloat
    var autoAvoid: Bool

    init(
        id: UUID = UUID(),
        vertexID: UUID,
        startPointID: UUID,
        endPointID: UUID,
        mode: GeometryAngleLabelMode = .degrees,
        name: String = "α",
        angleReference: GeometryAngleReference? = nil,
        labelOffset: CGPoint = .zero,
        radius: CGFloat = 32,
        autoAvoid: Bool = true
    ) {
        self.id = id
        self.vertexID = vertexID
        self.startPointID = startPointID
        self.endPointID = endPointID
        self.mode = mode
        self.name = name
        self.angleReference = angleReference
        self.labelOffset = labelOffset
        self.radius = max(8, radius)
        self.autoAvoid = autoAvoid
    }

    private enum CodingKeys: String, CodingKey {
        case id, vertexID, startPointID, endPointID, mode, name, angleReference, labelOffset, radius, autoAvoid
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        vertexID = try container.decode(UUID.self, forKey: .vertexID)
        startPointID = try container.decode(UUID.self, forKey: .startPointID)
        endPointID = try container.decode(UUID.self, forKey: .endPointID)
        mode = try container.decodeIfPresent(GeometryAngleLabelMode.self, forKey: .mode) ?? .degrees
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "α"
        angleReference = try container.decodeIfPresent(GeometryAngleReference.self, forKey: .angleReference)
        labelOffset = try container.decodeIfPresent(CGPoint.self, forKey: .labelOffset) ?? .zero
        radius = max(8, try container.decodeIfPresent(CGFloat.self, forKey: .radius) ?? 32)
        autoAvoid = try container.decodeIfPresent(Bool.self, forKey: .autoAvoid) ?? true
    }
}

struct GeometryAngleValue: Equatable {
    var degrees: CGFloat
    var radians: CGFloat { degrees * .pi / 180 }
}

/// Shared angle calculation used by every platform.
enum GeometryAngleCalculator {
    static func value(vertex: CGPoint, start: CGPoint, end: CGPoint) -> GeometryAngleValue? {
        let a = CGPoint(x: start.x - vertex.x, y: start.y - vertex.y)
        let b = CGPoint(x: end.x - vertex.x, y: end.y - vertex.y)
        let la = hypot(a.x, a.y)
        let lb = hypot(b.x, b.y)
        guard la > 0.0001, lb > 0.0001 else { return nil }

        let cosine = max(-1, min(1, (a.x * b.x + a.y * b.y) / (la * lb)))
        let radians = acos(cosine)
        return GeometryAngleValue(degrees: radians * 180 / .pi)
    }

    static func value(in model: GeometryModel, annotation: GeometryAngleAnnotation) -> GeometryAngleValue? {
        guard let vertex = model.points.first(where: { $0.id == annotation.vertexID }),
              let start = model.points.first(where: { $0.id == annotation.startPointID }),
              let end = model.points.first(where: { $0.id == annotation.endPointID }) else { return nil }
        return value(vertex: vertex.position, start: start.position, end: end.position)
    }

    static func targetDegrees(in model: GeometryModel, annotation: GeometryAngleAnnotation) -> CGFloat? {
        annotation.angleReference?.resolved(using: model.parameters)
    }
}

extension GeometryAngleAnnotation {
    func displayText(degrees: CGFloat) -> String? {
        switch mode {
        case .hidden: return nil
        case .degrees: return Self.formatDegrees(degrees)
        case .name: return name
        case .nameAndDegrees: return "\(name) = \(Self.formatDegrees(degrees))"
        }
    }

    private static func formatDegrees(_ value: CGFloat) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded.rounded() - rounded) < 0.001 {
            return "\(Int(rounded.rounded()))°"
        }
        return String(format: "%.1f°", Double(rounded))
    }
}
