import Foundation

/// Lightweight stroke preprocessing for natural-looking classroom handwriting.
///
/// The goal is closer to a good paper pen than to vector "beautification":
/// slow writing gets a little more stabilization, while fast writing stays close
/// to the original trajectory so the pen never feels like it is being dragged.
enum StrokeSmoother {
    struct Configuration {
        var enabled: Bool = true
        /// Maximum smoothing applied to a slow, straight section.
        var strength: Float = 0.42
        /// Turns sharper than this are kept crisp.
        var cornerAngleDegrees: Float = 55
        var minimumPointDistance: Float = 0.8
        var pressureStrength: Float = 0.28
        /// Approximate per-sample travel at which motion is considered fast.
        var fastDistance: Float = 14
        /// Approximate per-sample travel below which motion is considered slow.
        var slowDistance: Float = 2.5
    }

    static func smooth(_ input: [InkPoint], configuration: Configuration = Configuration()) -> [InkPoint] {
        guard configuration.enabled, input.count >= 3 else { return input }

        let points = deduplicated(input, minimumDistance: configuration.minimumPointDistance)
        guard points.count >= 3 else { return points }

        let maxStrength = max(0, min(1, configuration.strength))
        let pressureStrength = max(0, min(1, configuration.pressureStrength))
        let cornerCosine = cos(configuration.cornerAngleDegrees * .pi / 180)
        let slowDistance = max(0.001, configuration.slowDistance)
        let fastDistance = max(slowDistance + 0.001, configuration.fastDistance)

        var output: [InkPoint] = []
        output.reserveCapacity(points.count)
        output.append(points[0])

        for i in 1..<(points.count - 1) {
            let previous = points[i - 1]
            let current = points[i]
            let next = points[i + 1]

            let inVector = SIMD2(current.x - previous.x, current.y - previous.y)
            let outVector = SIMD2(next.x - current.x, next.y - current.y)
            let inLength = simdLength(inVector)
            let outLength = simdLength(outVector)

            guard inLength > 0.001, outLength > 0.001 else {
                output.append(current)
                continue
            }

            let cosine = simdDot(inVector / inLength, outVector / outLength)
            if cosine < cornerCosine {
                // Mathematical corners and handwriting turns should remain crisp.
                output.append(current)
                continue
            }

            // Distance-per-sample is a useful low-cost motion proxy. Slow movement
            // gets more stabilization; fast movement gets almost no correction.
            let travel = (inLength + outLength) * 0.5
            let fast01 = max(0, min(1, (travel - slowDistance) / (fastDistance - slowDistance)))
            let motionFactor = 1 - fast01
            let adaptiveStrength = maxStrength * motionFactor

            let averageX = (previous.x + 2 * current.x + next.x) * 0.25
            let averageY = (previous.y + 2 * current.y + next.y) * 0.25
            let targetX = current.x + (averageX - current.x) * adaptiveStrength
            let targetY = current.y + (averageY - current.y) * adaptiveStrength

            let averagePressure = (previous.pressure + 2 * current.pressure + next.pressure) * 0.25
            let pressure = current.pressure + (averagePressure - current.pressure) * pressureStrength

            output.append(InkPoint(x: targetX, y: targetY, pressure: pressure))
        }

        output.append(points[points.count - 1])
        return output
    }

    private static func deduplicated(_ input: [InkPoint], minimumDistance: Float) -> [InkPoint] {
        guard let first = input.first else { return [] }
        let thresholdSquared = minimumDistance * minimumDistance
        var output: [InkPoint] = [first]
        output.reserveCapacity(input.count)

        for point in input.dropFirst() {
            guard let last = output.last else { continue }
            let dx = point.x - last.x
            let dy = point.y - last.y
            if dx * dx + dy * dy >= thresholdSquared {
                output.append(point)
            } else {
                output[output.count - 1] = InkPoint(x: last.x, y: last.y, pressure: point.pressure)
            }
        }
        return output
    }
}

private func simdLength(_ value: SIMD2<Float>) -> Float {
    sqrt(value.x * value.x + value.y * value.y)
}

private func simdDot(_ lhs: SIMD2<Float>, _ rhs: SIMD2<Float>) -> Float {
    lhs.x * rhs.x + lhs.y * rhs.y
}
