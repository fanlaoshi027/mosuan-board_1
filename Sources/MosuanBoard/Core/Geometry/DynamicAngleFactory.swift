import CoreGraphics
import Foundation

/// Creates the common two-ray dynamic-angle construction used in teaching.
enum DynamicAngleFactory {
    static func makeGraphicObject(
        vertex: CGPoint,
        startLength: CGFloat = 180,
        endLength: CGFloat = 180,
        angleDegrees: CGFloat = 45,
        minimum: CGFloat = 10,
        maximum: CGFloat = 170,
        step: CGFloat = 1,
        name: String = "α",
        style: GraphicObject.Style = GraphicObject.Style()
    ) -> GraphicObject {
        DynamicAngle.make(
            vertex: vertex,
            startLength: startLength,
            endLength: endLength,
            angleDegrees: angleDegrees,
            minimum: minimum,
            maximum: maximum,
            step: step,
            name: name
        ).graphicObject(style: style)
    }
}
