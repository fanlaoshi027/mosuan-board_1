import CoreGraphics
import Foundation

/// Shared selection geometry used by the editor and, later, by PDF/whiteboard objects.
/// The model deliberately stores IDs instead of array indices so reordering objects does not
/// invalidate a multi-selection.
struct SelectionState: Equatable, Codable {
    private(set) var selectedIDs: [UUID] = []

    var isEmpty: Bool { selectedIDs.isEmpty }
    var count: Int { selectedIDs.count }

    mutating func clear() { selectedIDs.removeAll(keepingCapacity: true) }

    mutating func select(_ id: UUID, additive: Bool = false) {
        if !additive { selectedIDs.removeAll(keepingCapacity: true) }
        if !selectedIDs.contains(id) { selectedIDs.append(id) }
    }

    mutating func toggle(_ id: UUID) {
        if let index = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: index)
        } else {
            selectedIDs.append(id)
        }
    }

    func contains(_ id: UUID) -> Bool { selectedIDs.contains(id) }
}

struct SelectionBounds: Equatable, Codable {
    var minX: CGFloat
    var minY: CGFloat
    var maxX: CGFloat
    var maxY: CGFloat

    var width: CGFloat { maxX - minX }
    var height: CGFloat { maxY - minY }
    var center: CGPoint { CGPoint(x: (minX + maxX) * 0.5, y: (minY + maxY) * 0.5) }

    func contains(_ point: CGPoint, tolerance: CGFloat = 0) -> Bool {
        point.x >= minX - tolerance && point.x <= maxX + tolerance &&
        point.y >= minY - tolerance && point.y <= maxY + tolerance
    }

    func union(_ other: SelectionBounds) -> SelectionBounds {
        SelectionBounds(
            minX: min(minX, other.minX),
            minY: min(minY, other.minY),
            maxX: max(maxX, other.maxX),
            maxY: max(maxY, other.maxY)
        )
    }

    static func enclosing(_ bounds: [SelectionBounds]) -> SelectionBounds? {
        guard let first = bounds.first else { return nil }
        return bounds.dropFirst().reduce(first) { $0.union($1) }
    }
}

struct SelectionTransform: Equatable {
    var translation: CGSize = .zero
    var scale: CGSize = CGSize(width: 1, height: 1)
    var rotationDegrees: CGFloat = 0
    var rotationCenter: CGPoint?

    static let identity = SelectionTransform()
}
