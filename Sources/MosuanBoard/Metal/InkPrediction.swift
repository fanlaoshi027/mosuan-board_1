import Foundation

/// Tiny live-only pen-tip prediction used to hide input/render latency.
enum InkPrediction {
    struct Configuration { var maximumLookAhead: Float = 10; var minimumDistance: Float = 1.2; var maximumTurnDegrees: Float = 38; var maximumSamples: Int = 4 }
    static func preview(_ input: [InkPoint], configuration: Configuration = Configuration()) -> [InkPoint] {
        guard input.count >= 3 else { return input }
        let samples = Array(input.suffix(max(3, configuration.maximumSamples))); guard samples.count >= 3, let last = samples.last else { return input }
        let previous = samples[samples.count - 2], beforePrevious = samples[samples.count - 3], v1x = previous.x - beforePrevious.x, v1y = previous.y - beforePrevious.y, v2x = last.x - previous.x, v2y = last.y - previous.y, speed = hypot(v2x, v2y)
        guard speed >= configuration.minimumDistance else { return input }
        let len1 = max(hypot(v1x, v1y), 0.001), len2 = max(hypot(v2x, v2y), 0.001), cosine = max(-1, min(1, (v1x * v2x + v1y * v2y) / (len1 * len2))), angle = acos(cosine) * 180 / .pi
        guard angle <= configuration.maximumTurnDegrees else { return input }
        let speedFactor = max(0, min(1, (speed - 1.2) / 16)), lookAhead = min(configuration.maximumLookAhead, 2.0 + speed * (0.18 + 0.16 * speedFactor)), directionX = v2x / len2, directionY = v2y / len2
        var output = input; output.append(InkPoint(x: last.x + directionX * lookAhead, y: last.y + directionY * lookAhead, pressure: last.pressure)); return output
    }
}
