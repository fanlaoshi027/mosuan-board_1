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

        // Use the shared speed-aware smoother. This keeps Release behavior in
        // sync with the actual source implementation instead of maintaining a
        // second hard-coded smoothing algorithm in the build script.
        let smooth = StrokeSmoother.smooth(s)

        // Width smoothing is intentionally lighter than position smoothing so
        // pressure jitter disappears without introducing visible pen lag.
        var widths = smooth.map { strokeWidth($0.pressure, style) }
        if widths.count >= 3 {
            var filtered = widths
            for i in 1..<(widths.count - 1) {
                filtered[i] = widths[i] * 0.58 + (widths[i - 1] + widths[i + 1]) * 0.21
            }
            widths = filtered
        }

        // Gentle minimum-width ramp prevents a pressure spike from producing a
        // dot at the beginning or an abrupt heavy tail at the end.
        // Keep the taper subtle: the normal pen should still feel continuous,
        // with only a small nib/收笔 cue rather than a calligraphic effect.
        if widths.count >= 4 {
            let minimumWidth = Float(style.width) * 0.72
            widths[0] = max(widths[0] * 0.82, minimumWidth)
            widths[1] = max(widths[1] * 0.93, minimumWidth)
            widths[widths.count - 1] = max(widths[widths.count - 1] * 0.82, minimumWidth)
            widths[widths.count - 2] = max(widths[widths.count - 2] * 0.93, minimumWidth)
        }

        for i in 0..<(smooth.count - 1) {
            let p = smooth[i]
            let q = smooth[i + 1]
            let dx = q.x - p.x
            let dy = q.y - p.y
            let length = max(sqrt(dx * dx + dy * dy), 0.001)
            let nx = -dy / length
            let ny = dx / length
            let w0 = widths[i]
            let w1 = widths[i + 1]
            let a = viewPoint(from: SIMD2(p.x + nx * w0, p.y + ny * w0))
            let b = viewPoint(from: SIMD2(p.x - nx * w0, p.y - ny * w0))
            let c = viewPoint(from: SIMD2(q.x + nx * w1, q.y + ny * w1))
            let d = viewPoint(from: SIMD2(q.x - nx * w1, q.y - ny * w1))
            triangle(a, b, c, color: color, to: &out)
            triangle(c, b, d, color: color, to: &out)
        }

        for (index, p) in smooth.enumerated() {
            disk(viewPoint(from: SIMD2(p.x, p.y)), widths[index], color, to: &out)
        }
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

# Live-only short-horizon prediction. Never feed predicted samples into the
# recognizer or document model; they exist solely to hide render/input latency.
v = v.replace(
    'renderer.setStroke((isLineTool || (isSmartLineTool && smartLineDetected)) ? linePreview(from: points) : points)',
    'renderer.setStroke((isLineTool || (isSmartLineTool && smartLineDetected)) ? linePreview(from: points) : InkPrediction.preview(points))',
    1
)
view.write_text(v)
print("Applied shared speed-aware ink smoothing, light width smoothing, natural start/end width ramp, 4x MSAA, forgiving smart-line detection, and live-only short-horizon tip prediction.")
