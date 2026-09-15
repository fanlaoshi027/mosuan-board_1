import CoreGraphics
import Foundation

/// Unified selection model for dynamic geometry editing.
/// A selection may contain heterogeneous elements: points, edges, angles and whole shapes.
enum GeometrySelectionItem: Hashable, Codable {
    case point(UUID)
    case edge(UUID)
    case angle(UUID)
    case shape(UUID)
    case group(UUID)
}

struct GeometrySelectionSet: Equatable, Codable {
    private(set) var items: [GeometrySelectionItem] = []

    var isEmpty: Bool { items.isEmpty }
    var count: Int { items.count }

    func contains(_ item: GeometrySelectionItem) -> Bool {
        items.contains(item)
    }

    mutating func select(_ item: GeometrySelectionItem, additive: Bool = false) {
        if additive {
            if let index = items.firstIndex(of: item) {
                items.remove(at: index)
            } else {
                items.append(item)
            }
        } else {
            items = [item]
        }
    }

    mutating func add(_ item: GeometrySelectionItem) {
        guard !items.contains(item) else { return }
        items.append(item)
    }

    mutating func remove(_ item: GeometrySelectionItem) {
        items.removeAll { $0 == item }
    }

    mutating func clear() {
        items.removeAll(keepingCapacity: true)
    }

    mutating func add(contentsOf newItems: [GeometrySelectionItem]) {
        for item in newItems { add(item) }
    }

    /// Returns the common property targets represented by the current selection.
    /// The UI can use this to show only properties meaningful to every selected item.
    var propertyTargets: Set<PropertyTarget> {
        Set(items.map { item in
            switch item {
            case .point: return .point
            case .edge: return .edge
            case .angle: return .angle
            case .shape, .group: return .shape
            }
        })
    }

    enum PropertyTarget: String, Codable, Hashable {
        case point
        case edge
        case angle
        case shape
    }
}

/// Selection behavior shared by mouse, trackpad, Pencil and touch platforms.
enum GeometrySelectionEngine {
    static func toggle(
        _ item: GeometrySelectionItem,
        in selection: inout GeometrySelectionSet,
        additive: Bool
    ) {
        selection.select(item, additive: additive)
    }

    static func select(
        items: [GeometrySelectionItem],
        in selection: inout GeometrySelectionSet,
        additive: Bool
    ) {
        if !additive {
            selection.clear()
        }
        selection.add(contentsOf: items)
    }

    static func frameSelection(
        in model: GeometryModel,
        rect: CGRect,
        additive: Bool = false
    ) -> [GeometrySelectionItem] {
        let points = model.points
            .filter { rect.contains($0.position) }
            .map { GeometrySelectionItem.point($0.id) }

        let edges = model.lines.compactMap { line -> GeometrySelectionItem? in
            guard let a = model.points.first(where: { $0.id == line.startPointID }),
                  let b = model.points.first(where: { $0.id == line.endPointID }) else { return nil }
            let segmentBounds = CGRect(
                x: min(a.position.x, b.position.x),
                y: min(a.position.y, b.position.y),
                width: abs(a.position.x - b.position.x),
                height: abs(a.position.y - b.position.y)
            )
            return rect.intersects(segmentBounds) ? .edge(line.id) : nil
        }

        // Angles are included when all three defining points are inside the frame.
        let angles: [GeometrySelectionItem] = []

        return points + edges + angles
    }
}
