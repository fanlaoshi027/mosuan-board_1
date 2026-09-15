import CoreGraphics
import Foundation

/// Bridges independent GraphicObjects into one shared geometry model.
extension GraphicObjectStore {
    @discardableResult
    func mergeGeometryModels(for objectIDs: [UUID]) -> UUID? {
        let selected = objectIDs.compactMap { object(with: $0) }
        guard selected.count == objectIDs.count, !selected.isEmpty,
              selected.allSatisfy({ $0.kind == .line || $0.kind == .geometryPoint }) else { return nil }
        let models = selected.compactMap(\.geometryModel)
        guard models.count == selected.count else { return nil }
        let merged = GeometryModel(id: UUID(), points: models.flatMap(\.points), lines: models.flatMap(\.lines), angles: models.flatMap(\.angles), constraints: models.flatMap(\.constraints), parameters: models.flatMap(\.parameters), translations: models.flatMap(\.translations), translationGuides: models.flatMap(\.translationGuides))
        for object in selected { var copy = object; copy.geometryModel = merged; synchronizeGeometryProjection(&copy, model: merged); update(copy) }
        return merged.id
    }

    @discardableResult
    func createIntersectionPoint(firstLineObjectID: UUID, secondLineObjectID: UUID, name: String? = nil, segmentOnly: Bool = false) -> UUID? {
        guard let first = object(with: firstLineObjectID), let second = object(with: secondLineObjectID), first.kind == .line, second.kind == .line, isIdentityTransform(first.transform), isIdentityTransform(second.transform) else { return nil }
        guard let modelID = mergeGeometryModels(for: [firstLineObjectID, secondLineObjectID]), let source = object(with: firstLineObjectID), var model = source.geometryModel, let pointID = GeometryConstruction.createIntersectionPoint(model: &model, firstLineID: firstLineObjectID, secondLineID: secondLineObjectID, name: name, segmentOnly: segmentOnly), model.id == modelID, let point = model.points.first(where: { $0.id == pointID }) else { return nil }
        synchronizeGeometryModel(model)
        let style = GraphicObject.Style(strokeColor: first.style.strokeColor, strokeWidth: max(2, first.style.strokeWidth), opacity: first.style.opacity)
        let marker = GraphicObject(kind: .geometryPoint, style: style, geometry: GraphicObject.Geometry(points: [point.position]), geometryModel: model, geometryPointID: pointID)
        insert(marker)
        return marker.id
    }

    @discardableResult
    func moveLineEndpointResolved(id: UUID, endpoint: Int, to point: CGPoint) -> Bool {
        guard let object = object(with: id), object.kind == .line, endpoint == 0 || endpoint == 1, var model = object.geometryModel, let line = model.lines.first(where: { $0.id == id }) ?? model.lines.first else { return false }
        let pointID = endpoint == 0 ? line.startPointID : line.endPointID
        guard let pointIndex = model.points.firstIndex(where: { $0.id == pointID }), !model.points[pointIndex].isFixed else { return false }
        model.points[pointIndex].position = point
        GeometryConstraintSolver.apply(&model)
        synchronizeGeometryModel(model)
        return true
    }

    @discardableResult
    func synchronizeGeometryModel(_ model: GeometryModel) -> Bool {
        var changed = false
        for object in objects where object.geometryModel?.id == model.id {
            var copy = object
            copy.geometryModel = model
            synchronizeGeometryProjection(&copy, model: model)
            if copy != object { update(copy); changed = true }
        }
        return changed
    }

    private func synchronizeGeometryProjection(_ object: inout GraphicObject, model: GeometryModel) {
        switch object.kind {
        case .line, .arrow:
            guard let line = model.lines.first(where: { $0.id == object.id }) ?? model.lines.first, let a = model.points.first(where: { $0.id == line.startPointID }), let b = model.points.first(where: { $0.id == line.endPointID }) else { return }
            object.geometry.points = [a.position, b.position]
        case .geometryPoint:
            guard let pointID = object.geometryPointID, let point = model.points.first(where: { $0.id == pointID }) else { return }
            object.geometry.points = [point.position]
        default: break
        }
    }

    private func isIdentityTransform(_ transform: GraphicObject.Transform) -> Bool {
        abs(transform.position.x) < 0.0001 && abs(transform.position.y) < 0.0001 && abs(transform.scale.width - 1) < 0.0001 && abs(transform.scale.height - 1) < 0.0001 && abs(transform.rotation) < 0.0001 && abs(transform.rotationCenter.x) < 0.0001 && abs(transform.rotationCenter.y) < 0.0001
    }
}
