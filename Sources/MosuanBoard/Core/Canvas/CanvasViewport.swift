import CoreGraphics
import Foundation

/// Shared document viewport used by macOS/iPadOS and mirrored by native platform layers.
struct CanvasViewport: Equatable, Codable {
    var scale: CGFloat = 1
    var offset: CGPoint = .zero

    static let minScale: CGFloat = 0.25
    static let maxScale: CGFloat = 8

    mutating func reset() {
        scale = 1
        offset = .zero
    }

    mutating func setScale(_ newScale: CGFloat, keepingScreenPoint screenPoint: CGPoint = .zero) {
        let clamped = min(max(newScale, Self.minScale), Self.maxScale)
        let documentPoint = screenToDocument(screenPoint)
        scale = clamped
        offset = CGPoint(
            x: screenPoint.x - documentPoint.x * scale,
            y: screenPoint.y - documentPoint.y * scale
        )
    }

    mutating func zoom(by factor: CGFloat, around screenPoint: CGPoint = .zero) {
        setScale(scale * factor, keepingScreenPoint: screenPoint)
    }

    mutating func pan(by screenDelta: CGSize) {
        offset.x += screenDelta.width
        offset.y += screenDelta.height
    }

    func documentToScreen(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * scale + offset.x, y: point.y * scale + offset.y)
    }

    func screenToDocument(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - offset.x) / scale, y: (point.y - offset.y) / scale)
    }

    func documentLengthToScreen(_ value: CGFloat) -> CGFloat {
        value * scale
    }

    func screenLengthToDocument(_ value: CGFloat) -> CGFloat {
        value / scale
    }
}
