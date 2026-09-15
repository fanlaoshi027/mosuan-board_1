from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
renderer = ROOT / "Sources/MosuanBoard/Metal/InkRenderer.swift"
view = ROOT / "Sources/MosuanBoard/Metal/InkMetalView.swift"

r = renderer.read_text()

bg_start = r.index("    private func appendBackground(")
stroke_start = r.index("    private func appendStroke(", bg_start)
bg_block = r[bg_start:stroke_start]
if bg_block.count("{") > bg_block.count("}"):
    r = r[:stroke_start] + "    }\n" + r[stroke_start:]

start = r.index("    private func appendStroke(")
end = r.index("    private func appendSelection(", start)
new_stroke = r'''    private func appendStroke(_ s: [InkPoint], style: PenStyle, to out: inout [InkVertex]) {
        guard !s.isEmpty else { return }
        let color = metalColor(style)
        guard s.count > 1 else {
            let p = s[0]
            disk(viewPoint(from: SIMD2(p.x, p.y)), strokeWidth(p.pressure, style), color, to: &out)
            return
        }

        // Keep handwriting stabilization light and speed-aware.
        let smooth = StrokeSmoother.smooth(s)
        guard smooth.count > 1 else { return }

        // NSEvent samples can become sparse during fast writing. Densify the
        // trajectory before building the ink ribbon so long chords do not read
        // visually as separate "sections".
        var dense: [InkPoint] = []
        dense.reserveCapacity(max(smooth.count, Int(pathLength(smooth) / 1.5) + 2))
        dense.append(smooth[0])
        let maximumSpacing: Float = 1.5
        for i in 0..<(smooth.count - 1) {
            let p = smooth[i]
            let q = smooth[i + 1]
            let dx = q.x - p.x
            let dy = q.y - p.y
            let distance = sqrt(dx * dx + dy * dy)
            let steps = max(1, Int(ceil(distance / maximumSpacing)))
            if steps > 1 {
                for step in 1..<steps {
                    let t = Float(step) / Float(steps)
                    dense.append(InkPoint(
                        x: p.x + dx * t,
                        y: p.y + dy * t,
                        pressure: p.pressure + (q.pressure - p.pressure) * t
                    ))
                }
            }
            dense.append(q)
        }

        // Width smoothing removes pressure jitter without adding noticeable lag.
        var widths = dense.map { strokeWidth($0.pressure, style) }
        if widths.count >= 3 {
            var filtered = widths
            for i in 1..<(widths.count - 1) {
                filtered[i] = widths[i] * 0.62 + (widths[i - 1] + widths[i + 1]) * 0.19
            }
            widths = filtered
        }

        // Build one continuous ribbon. Each vertex uses the average tangent of
        // its neighboring samples, so turns share a smooth join instead of
        // producing a visible chain of independently oriented rectangles.
        for i in dense.indices {
            let current = dense[i]
            let previous = dense[max(0, i - 1)]
            let next = dense[min(dense.count - 1, i + 1)]
            var tx = next.x - previous.x
            var ty = next.y - previous.y
            let tangentLength = max(sqrt(tx * tx + ty * ty), 0.001)
            tx /= tangentLength
            ty /= tangentLength
            let nx = -ty
            let ny = tx
            let width = widths[i]
            let left = viewPoint(from: SIMD2(current.x + nx * width, current.y + ny * width))
            let right = viewPoint(from: SIMD2(current.x - nx * width, current.y - ny * width))

            if i > 0 {
                let previousPoint = dense[i - 1]
                let previousPrevious = dense[max(0, i - 2)]
                var ptx = current.x - previousPrevious.x
                var pty = current.y - previousPrevious.y
                let pl = max(sqrt(ptx * ptx + pty * pty), 0.001)
                ptx /= pl
                pty /= pl
                let pnx = -pty
                let pny = ptx
                let pw = widths[i - 1]
                let pLeft = viewPoint(from: SIMD2(previousPoint.x + pnx * pw, previousPoint.y + pny * pw))
                let pRight = viewPoint(from: SIMD2(previousPoint.x - pnx * pw, previousPoint.y - pny * pw))
                triangle(pLeft, pRight, left, color: color, to: &out)
                triangle(left, pRight, right, color: color, to: &out)
            }
        }

        // Round caps and joins keep the stroke closed at the ends and visually
        // continuous through small direction changes.
        for (index, p) in dense.enumerated() {
            disk(viewPoint(from: SIMD2(p.x, p.y)), widths[index], color, to: &out)
        }
    }

    private func pathLength(_ points: [InkPoint]) -> Float {
        guard points.count > 1 else { return 0 }
        var total: Float = 0
        for pair in zip(points, points.dropFirst()) {
            let dx = pair.1.x - pair.0.x
            let dy = pair.1.y - pair.0.y
            total += sqrt(dx * dx + dy * dy)
        }
        return total
    }
'''
r = r[:start] + new_stroke + r[end:]

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

r = r.replace(
    'descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm\n',
    'descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm\n        descriptor.rasterSampleCount = 4\n',
    1
)
renderer.write_text(r)

v = view.read_text()
v = v.replace('colorPixelFormat = .bgra8Unorm\n', 'colorPixelFormat = .bgra8Unorm\n        sampleCount = 4\n', 1)
v = v.replace(
    'if isLineTool || (isSmartLineTool && smartLineDetected) { let line = linePreview(from: points);',
    'let smartLine = isSmartLineTool && (smartLineDetected || (points.count >= 3 && LineGeometry.isLikelyStraight(points: points, tolerance: 18, minimumLength: 20)))\n        if isLineTool || smartLine { let line = linePreview(from: points);',
    1
)
v = v.replace('tolerance: 8, minimumLength: 30', 'tolerance: 18, minimumLength: 20', 1)
v = v.replace(
    'renderer.setStroke((isLineTool || (isSmartLineTool && smartLineDetected)) ? linePreview(from: points) : points)',
    'renderer.setStroke((isLineTool || (isSmartLineTool && smartLineDetected)) ? linePreview(from: points) : InkPrediction.preview(points))',
    1
)
view.write_text(v)
print("Applied continuous ribbon geometry, fast-path densification, light width smoothing, 4x MSAA, forgiving smart-line detection, and live-only short-horizon tip prediction.")
