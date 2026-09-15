import CoreGraphics
import Foundation

/// A simple 2D translation driven by a shared geometry parameter.
/// Direction is expressed in degrees; distance is resolved from a concrete value
/// or a named GeometryParameter.
struct GeometryTranslation: Codable, Equatable, Identifiable {
    let id: UUID
    var directionDegrees: CGFloat
    var distanceReference: GeometryLengthReference

    init(
        id: UUID = UUID(),
        directionDegrees: CGFloat = 0,
        distanceReference: GeometryLengthReference = .fixed(0)
    ) {
        self.id = id
        self.directionDegrees = directionDegrees
        self.distanceReference = distanceReference
    }

    func vector(using parameters: [GeometryParameter]) -> CGPoint? {
        guard let distance = distanceReference.resolved(using: parameters) else { return nil }
        let radians = directionDegrees * .pi / 180
        return CGPoint(x: distance * cos(radians), y: distance * sin(radians))
    }
}

enum GeometryTranslationGuideLineStyle: String, Codable, CaseIterable {
    case solid
    case dashed
}

/// Controls whether a translation vector is shown as a teaching aid.
/// The guide is visual-only and never becomes part of the geometry constraint graph.
enum GeometryTranslationGuideMode: String, Codable, CaseIterable {
    case hidden
    case vector
    case vectorAndDistance
}

/// Visual representation of a translation vector. The renderer can animate its
/// end point from the source point to the translated point, creating the familiar
/// "growing arrow" effect without storing a hidden line as a controller.
struct GeometryTranslationGuide: Codable, Equatable, Identifiable {
    let id: UUID
    var sourcePointID: UUID
    var mode: GeometryTranslationGuideMode
    var lineStyle: GeometryTranslationGuideLineStyle
    var arrowAtEnd: Bool

    init(
        id: UUID = UUID(),
        sourcePointID: UUID,
        mode: GeometryTranslationGuideMode = .vectorAndDistance,
        lineStyle: GeometryTranslationGuideLineStyle = .dashed,
        arrowAtEnd: Bool = true
    ) {
        self.id = id
        self.sourcePointID = sourcePointID
        self.mode = mode
        self.lineStyle = lineStyle
        self.arrowAtEnd = arrowAtEnd
    }
}

/// Lightweight description used by teaching overlays; it deliberately does not
/// reuse a GraphicObject so guides can never be accidentally selected or erased.
struct GeometryTranslationGuideState: Equatable {
    var progress: CGFloat = 1

    func endpoint(from source: CGPoint, translation: GeometryTranslation, parameters: [GeometryParameter]) -> CGPoint? {
        guard let vector = translation.vector(using: parameters) else { return nil }
        let t = max(0, min(1, progress))
        return CGPoint(
            x: source.x + vector.x * t,
            y: source.y + vector.y * t
        )
    }
}
