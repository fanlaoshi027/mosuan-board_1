import Foundation

/// Tiny live-only pen-tip prediction used to hide input/render latency.
///
/// The returned point is intentionally short-horizon and must never be persisted:
/// the real input samples remain the source of truth for recognition and undo.
enum InkPrediction {
    struct Configuration {
        var maximumLookAhead: Float = 10
        var minimumDistance: Float = 1.2
        var maximumTurnDegrees: Float = 38
        var maximumSamples: Int = 4
    }

    static func preview(_ input: [InkPoint], configuration: Configuration = Configuration()) -> [InkPoint] {
        guard input.count >= 3 else { return input }
        let samples = Array(input.suffix(max(3, configuration.maximumSamples)))
        guard samples.count >= 3, let last = samples.last else { return input }

        let previous = samples[samples.count - 2]
        let beforePrevious = samples[samples.count - 3]
        let v1x = previous.x - beforePrevious.x
        let v1y = previous.y - beforePrevious.y
        let v2x = last.x - previous.x
        let v2y = last.y - previous.y
        let speed = hypot(v2x, v2y)
        guard speed >= configuration.minimumDistance else { return input }

        let len1 = max(hypot(v1x, v1y), 0.001)
        let len2 = max(hypot(v2x, v2y), 0.001)
        let cosine = max(-1, min(1, (v1x * v2x + v1y * v2y) / (len1 * len2)))
        let angle = acos(cosine) * 180 / .pi
        guard angle <= configuration.maximumTurnDegrees else { return input }

        // Only predict a fraction of the current velocity. Fast strokes get a
        // little more lead, but the total lead is hard-capped so the tip never
        // visibly runs away from the real cursor/Pencil position.
        let speedFactor = max(0, min(1, (speed - 1.2) / 16))
        let lookAhead = min(configuration.maximumLookAhead, 2.0 + speed * (0.18 + 0.16 * speedFactor))
        let directionX = v2x / len2
        let directionY = v2y / len2
        let predicted = InkPoint(
            x: last.x + directionX * lookAhead,
            y: last.y + directionY * lookAhead,
            pressure: last.pressure
        )

        var output = input
        output.append(predicted)
        return output
    }
}
