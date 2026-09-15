import CoreGraphics
import Foundation

/// Runtime playback state for a dynamic isosceles triangle.
/// The driver is deliberately independent of SwiftUI/AppKit so the renderer,
/// recording pipeline and future platforms can share the same animation logic.
struct DynamicIsoscelesTriangleAnimationDriver: Equatable {
    private(set) var playingIDs: Set<UUID> = []

    mutating func setPlaying(_ playing: Bool, triangleID: UUID) {
        if playing {
            playingIDs.insert(triangleID)
        } else {
            playingIDs.remove(triangleID)
        }
    }

    mutating func toggle(triangleID: UUID) {
        if playingIDs.contains(triangleID) {
            playingIDs.remove(triangleID)
        } else {
            playingIDs.insert(triangleID)
        }
    }

    mutating func stop(triangleID: UUID) {
        playingIDs.remove(triangleID)
    }

    mutating func stopAll() {
        playingIDs.removeAll()
    }

    func isPlaying(triangleID: UUID) -> Bool {
        playingIDs.contains(triangleID)
    }

    var isPlayingAny: Bool {
        !playingIDs.isEmpty
    }

    /// Advances one triangle using its own mathematical animation parameters.
    /// The model remains the single source of truth for range, step, speed and loop mode.
    mutating func advance(
        triangle: inout DynamicIsoscelesTriangle,
        deltaTime: CGFloat
    ) {
        guard deltaTime > 0, isPlaying(triangleID: triangle.id) else { return }
        triangle.advanceAnimation(deltaTime: deltaTime)
    }
}
