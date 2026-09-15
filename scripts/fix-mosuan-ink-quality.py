from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
renderer = ROOT / "Sources/MosuanBoard/Metal/InkRenderer.swift"
view = ROOT / "Sources/MosuanBoard/Metal/InkMetalView.swift"

r = renderer.read_text()

# The renderer source remains intentionally small. The actual freehand stroke
# geometry now lives in the native Swift PerfectFreehandStroke port. This build
# patch only wires it into the existing Metal renderer and keeps the historical
# 4x MSAA / UI-quality fixes idempotent.
start = r.index("    private func appendStroke(")
end = r.index("    private func appendSelection(", start)
new_stroke = r'''    private func appendStroke(_ s: [InkPoint], style: PenStyle, to out: inout [InkVertex]) {
        guard !s.isEmpty else { return }
        let color = metalColor(style)
        let size = max(1.0, Float(style.width) * 2.0)
        let thinning: Float = style.pressureEnabled ? 0.5 : 0.0
        let outline = PerfectFreehandStroke.outline(
            for: s,
            options: .init(
                size: size,
                thinning: thinning,
                smoothing: 0.45,
                streamline: 0.28,
                simulatePressure: false,
                capStart: true,
                capEnd: true,
                last: true
            )
        )
        guard outline.count >= 3 else {
            let p = s[0]
            disk(viewPoint(from: SIMD2(p.x, p.y)), max(0.5, strokeWidth(p.pressure, style)), color, to: &out)
            return
        }
        appendFilledPolygon(outline, color: color, to: &out)
    }

    private func appendFilledPolygon(_ points: [SIMD2<Float>], color: SIMD4<Float>, to out: inout [InkVertex]) {
        guard points.count >= 3 else { return }
        let projected = points.map { viewPoint(from: $0) }
        var indices = Array(projected.indices)
        let area = polygonArea(projected)
        if area < 0 { indices.reverse() }

        while indices.count >= 3 {
            if indices.count == 3 {
                triangle(projected[indices[0]], projected[indices[1]], projected[indices[2]], color: color, to: &out)
                break
            }

            var earFound = false
            for i in indices.indices {
                let ia = indices[(i - 1 + indices.count) % indices.count]
                let ib = indices[i]
                let ic = indices[(i + 1) % indices.count]
                let a = projected[ia], b = projected[ib], c = projected[ic]
                if cross2(a, b, c) <= 0.0001 { continue }

                var containsOther = false
                for j in indices where j != ia && j != ib && j != ic {
                    if pointInTriangle(projected[j], a, b, c) {
                        containsOther = true
                        break
                    }
                }
                if containsOther { continue }

                triangle(a, b, c, color: color, to: &out)
                indices.remove(at: i)
                earFound = true
                break
            }

            if !earFound {
                // Safe fallback for pathological/self-touching outlines.
                for i in 1..<(indices.count - 1) {
                    triangle(projected[indices[0]], projected[indices[i]], projected[indices[i + 1]], color: color, to: &out)
                }
                break
            }
        }
    }

    private func polygonArea(_ points: [SIMD2<Float>]) -> Float {
        guard points.count >= 3 else { return 0 }
        var area: Float = 0
        for i in points.indices {
            let j = (i + 1) % points.count
            area += points[i].x * points[j].y - points[j].x * points[i].y
        }
        return area * 0.5
    }

    private func cross2(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Float {
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }

    private func pointInTriangle(_ p: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Bool {
        let c1 = cross2(a, b, p)
        let c2 = cross2(b, c, p)
        let c3 = cross2(c, a, p)
        let hasNegative = c1 < -0.0001 || c2 < -0.0001 || c3 < -0.0001
        let hasPositive = c1 > 0.0001 || c2 > 0.0001 || c3 > 0.0001
        return !(hasNegative && hasPositive)
    }
'''
r = r[:start] + new_stroke + r[end:]

if 'descriptor.rasterSampleCount = 4' not in r:
    r = r.replace(
        'descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm\n',
        'descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm\n        descriptor.rasterSampleCount = 4\n',
        1,
    )

r = r.replace('SIMD4(0.82,0.84,0.88,0.55)', 'SIMD4<Float>(0.82,0.84,0.88,0.55)')
r = r.replace('SIMD4(0.1,0.45,1,0.75)', 'SIMD4<Float>(0.1,0.45,1,0.75)')
r = r.replace('SIMD4(0.1,0.45,1,0.85)', 'SIMD4<Float>(0.1,0.45,1,0.85)')
r = r.replace('SIMD4(0.1,0.45,1,0.9)', 'SIMD4<Float>(0.1,0.45,1,0.9)')
r = r.replace('SIMD4(0.95,0.55,0.05,1)', 'SIMD4<Float>(0.95,0.55,0.05,1)')
r = r.replace('180.0/.pi', '180.0 / .pi')
r = r.replace('2*.pi', '2 * .pi')
r = r.replace('sourceRadius*CGFloat(0.32)', 'sourceRadius * CGFloat(0.32)')
r = r.replace('delta*CGFloat(180.0 / .pi)', 'delta * CGFloat(180.0 / .pi)')
r = r.replace('nx=-dy/l', 'nx = -dy / l')
r = r.replace('ny=dx/l', 'ny = dx / l')
renderer.write_text(r)

v = view.read_text()
if 'sampleCount = 4' not in v:
    v = v.replace('colorPixelFormat = .bgra8Unorm\n', 'colorPixelFormat = .bgra8Unorm\n        sampleCount = 4\n', 1)
v = v.replace(
    'if isLineTool || (isSmartLineTool && smartLineDetected) { let line = linePreview(from: points);',
    'let smartLine = isSmartLineTool && (smartLineDetected || (points.count >= 3 && LineGeometry.isLikelyStraight(points: points, tolerance: 18, minimumLength: 20)))\n        if isLineTool || smartLine { let line = linePreview(from: points);',
    1,
)
v = v.replace('tolerance: 8, minimumLength: 30', 'tolerance: 18, minimumLength: 20', 1)
v = v.replace(
    'renderer.setStroke((isLineTool || (isSmartLineTool && smartLineDetected)) ? linePreview(from: points) : points)',
    'renderer.setStroke((isLineTool || (isSmartLineTool && smartLineDetected)) ? linePreview(from: points) : InkPrediction.preview(points))',
    1,
)
view.write_text(v)

print("Using native Swift perfect-freehand stroke geometry with Metal fill, plus existing MSAA/prediction quality fixes.")
