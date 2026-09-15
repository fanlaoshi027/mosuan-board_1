import CoreGraphics
import Foundation

/// Interaction state for the two line workflows used by Mosuan Board:
/// direct line tool and pause-to-convert smart line.
struct LineInteraction {
    enum Mode {
        case direct
        case smart
    }

    var mode: Mode = .smart
    var points: [CGPoint] = []
    var isConverting = false
    var startPoint: CGPoint?
    var endPoint: CGPoint?

    /// A short pause is enough to trigger smart-line conversion; the caller owns
    /// the actual timer so this model stays independent from AppKit event timing.
    static let pauseThreshold: TimeInterval = 0.18

    mutating func begin(at point: CGPoint) {
        points = [point]
        startPoint = point
        endPoint = point
        isConverting = false
    }

    mutating func append(_ point: CGPoint) {
        points.append(point)
        endPoint = point
    }

    mutating func convertToStraightLine() -> Bool {
        guard mode == .smart, points.count >= 2,
              let first = points.first, let last = points.last,
              LineInteraction.isLikelyStraight(points) else { return false }
        startPoint = first
        endPoint = last
        points = [first, last]
        isConverting = true
        return true
    }

    mutating func moveEnd(to point: CGPoint) {
        guard isConverting, let first = startPoint else { return }
        endPoint = point
        points = [first, point]
    }

    mutating func finish() -> [CGPoint] {
        defer {
            points.removeAll(keepingCapacity: true)
            startPoint = nil
            endPoint = nil
            isConverting = false
        }
        return points
    }

    static func isLikelyStraight(_ points: [CGPoint], tolerance: CGFloat = 10) -> Bool {
        guard points.count >= 3, let first = points.first, let last = points.last else { return false }
        let dx = last.x - first.x
        let dy = last.y - first.y
        let length = hypot(dx, dy)
        guard length >= 18 else { return false }
        let maxDistance = points.dropFirst().dropLast().map { distance($0, toLineFrom: first, to: last) }.max() ?? 0
        return maxDistance <= tolerance
    }

    private static func distance(_ p: CGPoint, toLineFrom a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return abs(dy * p.x - dx * p.y + b.x * a.y - b.y * a.x) / max(hypot(dx, dy), 0.001)
    }
}
