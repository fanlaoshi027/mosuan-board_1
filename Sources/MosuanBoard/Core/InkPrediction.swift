import Foundation
import simd

/// Very short-horizon pen-tip prediction used only while a stroke is being drawn.
/// Predicted points are never committed to the document or sent to shape recognition.
enum InkPrediction {
    static func preview(_ input: [InkPoint]) -> [InkPoint] {
        guard input.count >= 4 else { return input }

        let count = input.count
        let a = input[count - 3]
        let b = input[count - 2]
        let c = input[count - 1]

        let ab = SIMD2<Float>(b.x - a.x, b.y - a.y)
        let bc = SIMD2<Float>(c.x - b.x, c.y - b.y)
        let abLength = simd_length(ab)
        let bcLength = simd_length(bc)
        guard abLength > 0.5, bcLength > 0.5 else { return input }

        let abDirection = ab / abLength
        let bcDirection = bc / bcLength
        let cosine = simd_dot(abDirection, bcDirection)
        // Sharp turns should not be predicted: preserving the real tip is more
        // important than hiding a few milliseconds of latency at a corner.
        guard cosine > 0.72 else { return input }

        let direction = simd_normalize(abDirection * 0.35 + bcDirection * 0.65)
        let distance = min(max(bcLength * 0.45, 2.0), 10.0)
        let predicted = SIMD2<Float>(c.x, c.y) + direction * distance

        var output = input
        output.append(InkPoint(x: predicted.x, y: predicted.y, pressure: c.pressure))
        return output
    }
}
