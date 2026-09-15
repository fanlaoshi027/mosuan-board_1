import CoreGraphics
import Foundation

/// Selection state for structured graphic objects. Selection is ID-based so
/// deleting/reordering objects never invalidates the selection identity.
struct GraphicSelectionModel: Equatable {
    private(set) var selectedIDs: [UUID] = []
    var rotationCenter: CGPoint?

    var isEmpty: Bool { selectedIDs.isEmpty }
    var count: Int { selectedIDs.count }

    mutating func clear() {
        selectedIDs.removeAll(keepingCapacity: true)
        rotationCenter = nil
    }

    mutating func select(_ id: UUID, additive: Bool = false) {
        if !additive { selectedIDs.removeAll(keepingCapacity: true) }
        if !selectedIDs.contains(id) { selectedIDs.append(id) }
        rotationCenter = nil
    }

    mutating func toggle(_ id: UUID) {
        if let index = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: index)
        } else {
            selectedIDs.append(id)
        }
        rotationCenter = nil
    }

    mutating func set(_ ids: [UUID]) {
        var unique: [UUID] = []
        unique.reserveCapacity(ids.count)
        for id in ids where !unique.contains(id) { unique.append(id) }
        selectedIDs = unique
        rotationCenter = nil
    }

    func contains(_ id: UUID) -> Bool { selectedIDs.contains(id) }

    func bounds(in store: GraphicObjectStore) -> CGRect? {
        selectedIDs.compactMap { store.bounds(of: $0) }.reduce(nil) { partial, next in
            partial?.union(next) ?? next
        }
    }

    func center(in store: GraphicObjectStore) -> CGPoint? {
        guard let bounds = bounds(in: store) else { return nil }
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }

    mutating func setRotationCenter(_ point: CGPoint) {
        guard !isEmpty else { return }
        rotationCenter = point
    }

    func effectiveRotationCenter(in store: GraphicObjectStore) -> CGPoint? {
        rotationCenter ?? center(in: store)
    }

    /// Returns object IDs intersecting a marquee rectangle. When `fullyContained`
    /// is false, touching the marquee is enough to select the object.
    static func ids(in rect: CGRect, store: GraphicObjectStore, fullyContained: Bool = false) -> [UUID] {
        let r = rect.standardized
        return store.objects.compactMap { object in
            guard let bounds = store.bounds(of: object) else { return nil }
            let hit = fullyContained ? r.contains(bounds) : r.intersects(bounds)
            return hit ? object.id : nil
        }
    }
}
