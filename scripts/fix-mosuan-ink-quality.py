from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
renderer = ROOT / "Sources/MosuanBoard/Metal/InkRenderer.swift"
view = ROOT / "Sources/MosuanBoard/Metal/InkMetalView.swift"

r = renderer.read_text()
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

        // The perfect-freehand algorithm returns one closed outline polygon.
        // For the current Metal renderer, a fan from the polygon centroid keeps
        // this integration tiny and avoids introducing another rendering engine.
        var center = SIMD2<Float>(0, 0)
        for p in outline { center += p }
        center /= Float(outline.count)
        let viewCenter = viewPoint(from: center)
        for i in outline.indices {
            let next = (i + 1) % outline.count
            triangle(viewCenter, viewPoint(from: outline[i]), viewPoint(from: outline[next]), color: color, to: &out)
        }
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

print("Using native Swift perfect-freehand geometry with Metal fill, plus existing MSAA/prediction quality fixes.")
