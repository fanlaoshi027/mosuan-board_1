import Foundation
import simd

//
// MIT License
// Copyright (c) 2021 Steve Ruiz
//
// This file contains a Swift adaptation of the core stroke-generation ideas
// from steveruizok/perfect-freehand. The upstream project is MIT licensed.
// https://github.com/steveruizok/perfect-freehand
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

/// A small native Swift port of the core `perfect-freehand` stroke pipeline.
/// It turns sampled center-line points into a filled outline polygon so the
/// existing Metal renderer can draw it without introducing JavaScript or a
/// second rendering engine.
enum PerfectFreehandStroke {
    struct Options {
        var size: Float
        var thinning: Float = 0.5
        var smoothing: Float = 0.5
        var streamline: Float = 0.35
        var simulatePressure: Bool = false
        var capStart: Bool = true
        var capEnd: Bool = true
        var last: Bool = true

        init(size: Float, thinning: Float = 0.5, smoothing: Float = 0.5, streamline: Float = 0.35, simulatePressure: Bool = false, capStart: Bool = true, capEnd: Bool = true, last: Bool = true) {
            self.size = max(0.5, size)
            self.thinning = max(-1, min(1, thinning))
            self.smoothing = max(0, min(1, smoothing))
            self.streamline = max(0, min(1, streamline))
            self.simulatePressure = simulatePressure
            self.capStart = capStart
            self.capEnd = capEnd
            self.last = last
        }
    }

    private struct StrokePoint {
        var point: SIMD2<Float>
        var pressure: Float
        var vector: SIMD2<Float>
        var distance: Float
        var runningLength: Float
    }

    private static let minStreamlineT: Float = 0.15
    private static let streamlineRange: Float = 0.85
    private static let minRadius: Float = 0.01
    private static let minPointDistance: Float = 0.35
    private static let startCapSegments = 12
    private static let endCapSegments = 20
    private static let cornerCapSegments = 10

    static func outline(for input: [InkPoint], options: Options) -> [SIMD2<Float>] {
        guard !input.isEmpty else { return [] }
        let points = makeStrokePoints(input, options: options)
        guard !points.isEmpty else { return [] }
        if points.count == 1 {
            let p = points[0].point
            let radius = strokeRadius(size: options.size, thinning: options.thinning, pressure: points[0].pressure)
            return circle(center: p, radius: radius, segments: 18)
        }

        let totalLength = points.last?.runningLength ?? 0
        var left: [SIMD2<Float>] = []
        var right: [SIMD2<Float>] = []
        left.reserveCapacity(points.count + 24)
        right.reserveCapacity(points.count + 24)

        var previousPressure = points[0].pressure
        var previousVector = points[0].vector
        var previousLeft = points[0].point
        var previousRight = points[0].point
        var previousWasCorner = false

        for i in points.indices {
            let current = points[i]
            let isLast = i == points.count - 1
            var pressure = current.pressure
            if options.simulatePressure {
                pressure = simulatedPressure(previousPressure, distance: current.distance, size: options.size)
            }
            let radius = max(minRadius, strokeRadius(size: options.size, thinning: options.thinning, pressure: pressure))

            let nextVector = isLast ? current.vector : points[i + 1].vector
            let nextDot = isLast ? 1 : dot(current.vector, nextVector)
            let previousDot = dot(current.vector, previousVector)
            let isSharp = previousDot < -0.05 && !previousWasCorner
            let nextIsSharp = nextDot < -0.05

            if isSharp || nextIsSharp {
                let offset = perpendicular(normalized(previousVector)) * radius
                var lastLeft = current.point
                var lastRight = current.point
                for n in 0...cornerCapSegments {
                    let t = Float(n) / Float(cornerCapSegments)
                    lastLeft = rotate(current.point - offset, around: current.point, angle: .pi * t)
                    lastRight = rotate(current.point + offset, around: current.point, angle: -.pi * t)
                    left.append(lastLeft)
                    right.append(lastRight)
                }
                previousLeft = lastLeft
                previousRight = lastRight
                previousWasCorner = nextIsSharp
                previousPressure = pressure
                previousVector = current.vector
                continue
            }
            previousWasCorner = false

            if isLast {
                let offset = perpendicular(normalized(current.vector)) * radius
                left.append(current.point - offset)
                right.append(current.point + offset)
                previousPressure = pressure
                previousVector = current.vector
                continue
            }

            let blended = normalized(nextVector + current.vector)
            let offset = perpendicular(blended) * radius
            let leftPoint = current.point - offset
            let rightPoint = current.point + offset
            let minimumSquared = max(minPointDistance, options.size * (1 - options.smoothing) * 0.06)
            if i <= 1 || simd_length_squared(leftPoint - previousLeft) > minimumSquared * minimumSquared {
                left.append(leftPoint)
                previousLeft = leftPoint
            }
            if i <= 1 || simd_length_squared(rightPoint - previousRight) > minimumSquared * minimumSquared {
                right.append(rightPoint)
                previousRight = rightPoint
            }
            previousPressure = pressure
            previousVector = current.vector
        }

        guard !left.isEmpty, !right.isEmpty else { return [] }
        let first = points[0].point
        let last = points[points.count - 1].point
        var startCap: [SIMD2<Float>] = []
        var endCap: [SIMD2<Float>] = []

        if options.capStart {
            let direction = normalized(right[0] - first)
            startCap = roundCap(center: first, start: right[0], direction: direction, segments: startCapSegments, angle: .pi)
        } else {
            startCap = [first + (left[0] - first) * 0.02, first - (right[0] - first) * 0.02]
        }

        if options.capEnd {
            let radius = max(simd_length(last - right[right.count - 1]), minRadius)
            let direction = normalized(-points[points.count - 1].vector)
            let start = last + direction * radius
            endCap = roundCap(center: last, start: start, direction: direction, segments: endCapSegments, angle: .pi * 1.5)
        } else {
            endCap = [last]
        }

        return left + endCap + right.reversed() + startCap
    }

    private static func makeStrokePoints(_ input: [InkPoint], options: Options) -> [StrokePoint] {
        let t = minStreamlineT + (1 - options.streamline) * streamlineRange
        var source = input
        if source.count == 1 {
            let p = source[0]
            source.append(InkPoint(x: p.x + 1, y: p.y + 1, pressure: p.pressure))
        } else if source.count == 2 {
            let a = source[0]
            let b = source[1]
            source = (0...4).map { i in
                let f = Float(i) / 4
                return InkPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f, pressure: a.pressure + (b.pressure - a.pressure) * f)
            }
        }

        var result: [StrokePoint] = []
        result.reserveCapacity(source.count)
        let first = SIMD2(source[0].x, source[0].y)
        var previous = first
        var running: Float = 0
        var previousPressure = source[0].pressure
        result.append(StrokePoint(point: first, pressure: previousPressure, vector: SIMD2(1, 1), distance: 0, runningLength: 0))

        for i in 1..<source.count {
            let raw = SIMD2(source[i].x, source[i].y)
            let point = options.last && i == source.count - 1 ? raw : previous + (raw - previous) * t
            if simd_distance(previous, point) < 0.0001 { continue }
            let distance = simd_distance(previous, point)
            running += distance
            let vector = normalized(previous - point)
            let pressure = max(0, min(1, source[i].pressure))
            result.append(StrokePoint(point: point, pressure: pressure, vector: vector, distance: distance, runningLength: running))
            previous = point
            previousPressure = pressure
        }
        if result.count > 1 { result[0].vector = result[1].vector }
        _ = previousPressure
        return result
    }

    private static func strokeRadius(size: Float, thinning: Float, pressure: Float) -> Float {
        size * (0.5 - thinning * (0.5 - max(0, min(1, pressure))))
    }

    private static func simulatedPressure(_ previous: Float, distance: Float, size: Float) -> Float {
        let speed = min(1, distance / max(size, 0.001))
        let target = min(1, 1 - speed)
        return min(1, previous + (target - previous) * (speed * 0.275))
    }

    private static func normalized(_ value: SIMD2<Float>) -> SIMD2<Float> {
        let length = simd_length(value)
        return length > 0.0001 ? value / length : SIMD2(1, 0)
    }

    private static func perpendicular(_ value: SIMD2<Float>) -> SIMD2<Float> {
        SIMD2(value.y, -value.x)
    }

    private static func dot(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        simd_dot(normalized(a), normalized(b))
    }

    private static func rotate(_ point: SIMD2<Float>, around center: SIMD2<Float>, angle: Float) -> SIMD2<Float> {
        let s = sin(angle)
        let c = cos(angle)
        let p = point - center
        return SIMD2(p.x * c - p.y * s, p.x * s + p.y * c) + center
    }

    private static func roundCap(center: SIMD2<Float>, start: SIMD2<Float>, direction: SIMD2<Float>, segments: Int, angle: Float) -> [SIMD2<Float>] {
        let radius = simd_distance(center, start)
        guard radius > 0.0001 else { return [] }
        var result: [SIMD2<Float>] = []
        result.reserveCapacity(segments)
        let startAngle = atan2(start.y - center.y, start.x - center.x)
        let sign: Float = dot(direction, SIMD2(cos(startAngle), sin(startAngle))) >= 0 ? 1 : -1
        for i in 1...segments {
            let t = Float(i) / Float(segments)
            result.append(center + SIMD2(cos(startAngle + angle * t * sign), sin(startAngle + angle * t * sign)) * radius)
        }
        return result
    }

    private static func circle(center: SIMD2<Float>, radius: Float, segments: Int) -> [SIMD2<Float>] {
        (0..<segments).map { i in
            let a = Float(i) / Float(segments) * 2 * .pi
            return center + SIMD2(cos(a), sin(a)) * radius
        }
    }
}
