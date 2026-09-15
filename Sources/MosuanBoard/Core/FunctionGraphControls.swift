import CoreGraphics
import Foundation

/// Editable handles exposed immediately after creating a quadratic function.
/// The graph itself remains a structured function object rather than a bitmap/stroke.
enum FunctionGraphControlKind: String, Codable, Equatable {
    case vertex
    case leftDomain
    case rightDomain
}

struct FunctionGraphControlPoint: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: FunctionGraphControlKind
    var position: CGPoint

    init(id: UUID = UUID(), kind: FunctionGraphControlKind, position: CGPoint) {
        self.id = id
        self.kind = kind
        self.position = position
    }
}

extension GraphicObject {
    /// Control points shown when a quadratic graph is first created/selected.
    /// Vertex moves change the function's b/c while preserving a; domain handles
    /// only change the visible x range.
    func functionGraphControlPoints() -> [FunctionGraphControlPoint] {
        guard kind == .functionGraph, geometry.points.count >= 2 else { return [] }

        let parameters = geometry.parameters
        let a = parameters["a"] ?? 1
        let b = parameters["b"] ?? 0
        let c = parameters["c"] ?? 0
        let vertexX = -b / (2 * a)
        let vertexY = a * vertexX * vertexX + b * vertexX + c
        let leftX = parameters["xMin"] ?? Double(geometry.points.first?.x ?? -5)
        let rightX = parameters["xMax"] ?? Double(geometry.points.last?.x ?? 5)

        return [
            FunctionGraphControlPoint(kind: .vertex, position: CGPoint(x: vertexX, y: vertexY)),
            FunctionGraphControlPoint(kind: .leftDomain, position: CGPoint(x: leftX, y: a * leftX * leftX + b * leftX + c)),
            FunctionGraphControlPoint(kind: .rightDomain, position: CGPoint(x: rightX, y: a * rightX * rightX + b * rightX + c))
        ]
    }
}

/// Interaction rule for structured drawing tools:
///
/// 1. Creating a line or quadratic function automatically selects the new object.
/// 2. Its control points are visible immediately after creation.
/// 3. Clicking blank canvas clears selection/control points.
/// 4. Starting a new drawing gesture clears the previous selection before drawing.
/// 5. Selecting another object transfers the control points to that object.
///
/// This keeps drawing and editing separate: the user never needs to manually enter
/// selection mode just to adjust a freshly created geometric object.
struct DrawingSelectionPolicy {
    static let selectsCreatedObject = true
    static let clearsOnBlankClick = true
    static let clearsOnNewDrawing = true
}
