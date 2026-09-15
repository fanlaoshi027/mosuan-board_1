import CoreGraphics
import Foundation

/// A geometric line primitive backed by two named points.
/// Segment length can be concrete or driven by a shared named parameter.
struct GeometryLine: Codable, Equatable, Identifiable {
    enum Kind: String, Codable, CaseIterable {
        case line
        case segment
        case ray
    }

    let id: UUID
    var startPointID: UUID
    var endPointID: UUID
    var kind: Kind
    var lengthReference: GeometryLengthReference?

    init(
        id: UUID = UUID(),
        startPointID: UUID,
        endPointID: UUID,
        kind: Kind = .segment,
        lengthReference: GeometryLengthReference? = nil
    ) {
        self.id = id
        self.startPointID = startPointID
        self.endPointID = endPointID
        self.kind = kind
        self.lengthReference = lengthReference
    }

    var hasLengthConstraint: Bool {
        lengthReference != nil && kind == .segment
    }
}
