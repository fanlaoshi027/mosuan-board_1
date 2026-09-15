import Foundation
import simd

/// Generates pen-tip variation even when the input device has no usable pressure.
/// The effect is deterministic and is based on stroke speed plus entry/exit taper,
/// so a normal capacitive/active stylus can still produce a handwriting-like nib.
struct MosuanInkDynamics {
    var minimumFactor: Float = 0.58
    var maximumFactor: Float = 1.18
    var speedForThinLine: Float = 1800
    var speedForThickLine: Float = 80
    var tipLength: Int = 5

    private(set) var pointCount = 0
    private var lastPosition: SIMD2<Float>?
    private var lastTimestamp: TimeInterval?

    mutating func reset() {
        pointCount = 0
        lastPosition = nil
        lastTimestamp = nil
    }

    /// Returns a synthetic pressure value in 0...1 suitable for the existing
    /// InkPoint/Metal pipeline. Real Pencil pressure can bypass this model.
    mutating func syntheticPressure(position: SIMD2<Float>, timestamp: TimeInterval, phase: MosuanPointerEvent.Phase) -> Float {
        if phase == .began {
            reset()
        }

        pointCount += 1

        var speed: Float = speedForThickLine
        if let previous = lastPosition, let previousTime = lastTimestamp {
            let dt = max(Float(timestamp - previousTime), 1.0 / 240.0)
            speed = simd_distance(position, previous) / dt
        }

        lastPosition = position
        lastTimestamp = timestamp

        let speedT = min(max((speed - speedForThickLine) / max(speedForThinLine - speedForThickLine, 1), 0), 1)
        let speedFactor = maximumFactor + (minimumFactor - maximumFactor) * speedT

        // A short entry/exit taper gives the stroke a visible nib/锋 without
        // requiring pressure hardware. Keep the taper subtle for natural writing.
        let edgeTaper: Float
        if phase == .ended {
            edgeTaper = 0.72
        } else if pointCount <= tipLength {
            edgeTaper = 0.72 + 0.28 * Float(pointCount) / Float(max(tipLength, 1))
        } else {
            edgeTaper = 1
        }

        let factor = min(max(speedFactor * edgeTaper, minimumFactor * 0.75), maximumFactor)
        return min(max((factor - minimumFactor) / max(maximumFactor - minimumFactor, 0.001), 0), 1)
    }
}
