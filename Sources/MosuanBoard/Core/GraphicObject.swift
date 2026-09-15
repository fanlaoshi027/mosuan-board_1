import CoreGraphics
import Foundation

/// The common editable object model used by the Mosuan Board canvas.
/// Existing freehand strokes remain supported; future tools can adopt these
/// structured objects without changing selection/transform semantics.
struct GraphicObject: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case freehandStroke
        case line
        case arrow
        case polygon
        case rectangle
        case ellipse
        case coordinateSystem
        case functionGraph
        case parameterizedTriangle
        case dynamicAngle
        case geometryPoint
        case group
    }

    struct Transform: Codable, Equatable {
        var position: CGPoint = .zero
        var scale: CGSize = CGSize(width: 1, height: 1)
        var rotation: CGFloat = 0
        var rotationCenter: CGPoint = .zero
    }

    struct Style: Codable, Equatable {
        var strokeColor: RGBAColor = .black
        var strokeWidth: CGFloat = 2
        var opacity: CGFloat = 1
        var lineStyle: PenStyle.LineStyle = .solid
        var fillEnabled: Bool = false
        var fillColor: RGBAColor = .black
        var fillOpacity: CGFloat = 0
    }

    struct Geometry: Codable, Equatable {
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
        var expression: String?
        var parameters: [String: Double] = [:]
    }

    let id: UUID
    var kind: Kind
    var transform: Transform
    var style: Style
    var geometry: Geometry
    var children: [GraphicObject]
    var geometryModel: GeometryModel?
    var geometryPointID: UUID?
    var triangleModel: ParameterizedTriangle?
    var dynamicAngleModel: DynamicAngle?

    init(id: UUID = UUID(), kind: Kind, transform: Transform = Transform(), style: Style = Style(), geometry: Geometry = Geometry(), children: [GraphicObject] = [], geometryModel: GeometryModel? = nil, geometryPointID: UUID? = nil, triangleModel: ParameterizedTriangle? = nil, dynamicAngleModel: DynamicAngle? = nil) {
        self.id=id; self.kind=kind; self.transform=transform; self.style=style; self.geometry=geometry
        self.children=children; self.geometryModel=geometryModel; self.geometryPointID=geometryPointID; self.triangleModel=triangleModel; self.dynamicAngleModel=dynamicAngleModel
    }
}

extension GraphicObject {
    static func line(from start: CGPoint, to end: CGPoint, style: Style = Style()) -> GraphicObject {
        let startID = UUID(), endID = UUID(), lineID = UUID()
        let model = GeometryModel(
            points: [GeometryPoint(id: startID, position: start), GeometryPoint(id: endID, position: end)],
            lines: [GeometryLine(id: lineID, startPointID: startID, endPointID: endID, kind: .segment)]
        )
        return GraphicObject(id: lineID, kind: .line, style: style, geometry: Geometry(points: [start, end]), geometryModel: model)
    }

    static func geometryPoint(position: CGPoint, style: Style = Style()) -> GraphicObject {
        let pointID = UUID()
        let model = GeometryModel(points: [GeometryPoint(id: pointID, position: position)])
        return GraphicObject(kind: .geometryPoint, style: style, geometry: Geometry(points: [position]), geometryModel: model, geometryPointID: pointID)
    }

    static func polygon(points: [CGPoint], style: Style = Style()) -> GraphicObject { GraphicObject(kind: .polygon, style: style, geometry: Geometry(points: points)) }
    static func rectangle(_ rect: CGRect, style: Style = Style()) -> GraphicObject { GraphicObject(kind: .rectangle, style: style, geometry: Geometry(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)) }
    static func ellipse(_ rect: CGRect, style: Style = Style()) -> GraphicObject { GraphicObject(kind: .ellipse, style: style, geometry: Geometry(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)) }

    static func isoscelesTriangle(anchor: CGPoint, legLength: CGFloat = 120, apexAngleDegrees: CGFloat = 60, style: Style = Style()) -> GraphicObject {
        let model = ParameterizedTriangle(kind: .isosceles, anchor: anchor, legLength: legLength, apexAngleDegrees: apexAngleDegrees)
        return GraphicObject(kind: .parameterizedTriangle, style: style, geometry: Geometry(points: model.vertices()), triangleModel: model)
    }
}
