import AppKit
import MetalKit
import simd

final class InkMetalView: MTKView {
    private static let mosuanClipboardType = NSPasteboard.PasteboardType("com.fanlaoshi.mosuan.selection")

    private let renderer: InkRenderer
    private let lassoOverlay = LassoOverlayView()
    private var points: [InkPoint] = []
    private var eraserPoints: [SIMD2<Float>] = []
    private var lastEraserPoint: SIMD2<Float>?
    private var active = false
    private var selectionDrag = false
    private var lassoActive = false
    private var lassoPoints: [SIMD2<Float>] = []
    private var lassoOperation: SelectionOperation = .replace
    private var temporarySelectHeld = false
    private var resizeHandle: InkRenderer.SelectionHandle?
    private var lineEndpointDrag: (id: UUID, endpoint: Int)?
    private var polygonVertexDrag: (id: UUID, vertexIndex: Int)?
    private var dynamicAngleDragID: UUID?
    private var dynamicIsoscelesTriangleDragID: UUID?
    private var dynamicTrianglePlaybackHistoryActive = false
    private var dynamicTriangleParameterHistoryActive = false
    private var rotationDrag = false
    private var rotationCenterDrag = false
    private var panDrag = false
    private var spaceHeld = false
    private var middleButtonHeld = false
    private var lastPoint = SIMD2<Float>(0, 0)
    private var lastRotationPoint = SIMD2<Float>(0, 0)
    private var smartLineDetected = false
    private var smartLineWorkItem: DispatchWorkItem?
    private var polygonModel = PolygonToolModel()

    var isUserInteractionEnabledForTool = true
    var isSelectionTool = false
    var isPanTool = false
    var isLineTool = false
    var isSmartLineTool = false
    var isPolygonTool = false
    var isOneStrokeTool = false
    var isDynamicAngleTool = false
    var isDynamicIsoscelesTriangleTool = false
    var isEraserTool = false
    var backgroundPattern = 0 { didSet { renderer.setBackgroundPattern(backgroundPattern) } }
    var onHistoryChanged: (() -> Void)?
    var onSelectionChanged: (() -> Void)?
    var onPageStateChanged: ((CanvasPageState) -> Void)?
    var onZoomChanged: ((Int) -> Void)?
    var penStyle = PenStyle() { didSet { renderer.setPenStyle(penStyle) } }
    var boardBackground = SIMD4<Float>(1, 1, 1, 1) { didSet { renderer.setBackgroundColor(boardBackground) } }
    var displayInverted = false { didSet { renderer.setDisplayInverted(displayInverted) } }
    var canUndo: Bool { renderer.canUndo }
    var canRedo: Bool { renderer.canRedo }
    var hasSelection: Bool { renderer.hasSelection }
    var selectionCount: Int { renderer.selectionCount }
    var selectedRotationDegrees: Double { renderer.selectedRotationDegrees }
    var selectedDynamicAngleDegrees: CGFloat? { renderer.selectedDynamicAngleDegrees() }
    var isSelectedDynamicAnglePlaying: Bool { renderer.isSelectedDynamicAnglePlaying() }
    var selectedDynamicIsoscelesTriangleDegrees: CGFloat? { renderer.selectedDynamicIsoscelesTriangleDegrees() }
    var selectedDynamicIsoscelesTriangleLegLength: CGFloat? { renderer.selectedDynamicIsoscelesTriangleLegLength() }
    var zoomPercent: Int { renderer.zoomPercent }
    var selectionBoundsInView: CGRect? { renderer.selectionBoundsInView() }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    init(frame frameRect: NSRect = .zero) {
        guard let device = MTLCreateSystemDefaultDevice(), let renderer = InkRenderer(device: device) else { fatalError("Metal is unavailable on this Mac") }
        self.renderer = renderer
        super.init(frame: frameRect, device: device)
        configureMetal()
        renderer.setPenStyle(penStyle)
    }

    required init(coder: NSCoder) {
        guard let device = MTLCreateSystemDefaultDevice(), let renderer = InkRenderer(device: device) else { fatalError("Metal is unavailable on this Mac") }
        self.renderer = renderer
        super.init(coder: coder)
        configureMetal()
        renderer.setPenStyle(penStyle)
    }

    private func configureMetal() {
        delegate = renderer
        isPaused = true
        enableSetNeedsDisplay = true
        framebufferOnly = true
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        lassoOverlay.isHidden = true
        lassoOverlay.autoresizingMask = [.width, .height]
        addSubview(lassoOverlay)
    }

    func loadPageState(_ state: CanvasPageState) {
        polygonModel.cancel()
        polygonVertexDrag = nil
        dynamicAngleDragID = nil
        dynamicIsoscelesTriangleDragID = nil
        dynamicTrianglePlaybackHistoryActive = false
        dynamicTriangleParameterHistoryActive = false
        lassoActive = false
        lassoPoints.removeAll(keepingCapacity: true)
        lassoOverlay.update(points: [], visible: false)
        renderer.importPageState(state)
        onHistoryChanged?()
        onSelectionChanged?()
        draw()
    }

    func currentPageState() -> CanvasPageState { renderer.exportPageState() }
    func undo() { renderer.undo(); notifyState(); draw() }
    func redo() { renderer.redo(); notifyState(); draw() }
    func deleteSelected() { renderer.deleteSelected(); notifyState(); draw() }
    func setSelectedRotationDegrees(_ d: Double) { renderer.setSelectedRotationDegrees(d); notifyState(); draw() }
    func setSelectedDynamicAngleDegrees(_ d: CGFloat) { renderer.beginHistoryTransaction(); if renderer.setSelectedDynamicAngleDegrees(d) { renderer.endHistoryTransaction(); notifyState(); draw() } else { renderer.endHistoryTransaction() } }
    func toggleSelectedDynamicAnglePlayback() { renderer.toggleSelectedDynamicAnglePlayback(); onSelectionChanged?(); draw() }
    func stopDynamicAnglePlayback() { renderer.stopAllDynamicAngleAnimations(); onSelectionChanged?(); draw() }
    func beginDynamicTrianglePlaybackHistory() {
        guard !dynamicTrianglePlaybackHistoryActive else { return }
        dynamicTrianglePlaybackHistoryActive = true
        renderer.beginHistoryTransaction()
    }
    func endDynamicTrianglePlaybackHistory() {
        guard dynamicTrianglePlaybackHistoryActive else { return }
        dynamicTrianglePlaybackHistoryActive = false
        renderer.endHistoryTransaction()
        notifyState()
        draw()
    }
    func beginDynamicTriangleParameterEditHistory() {
        guard !dynamicTriangleParameterHistoryActive else { return }
        dynamicTriangleParameterHistoryActive = true
        renderer.beginHistoryTransaction()
    }
    func endDynamicTriangleParameterEditHistory() {
        guard !dynamicTriangleParameterHistoryActive else { return }
        dynamicTriangleParameterHistoryActive = false
        renderer.endHistoryTransaction()
        notifyState()
        draw()
    }
    func setSelectedDynamicIsoscelesTriangleDegrees(_ d: CGFloat) {
        let ownsTransaction = !dynamicTrianglePlaybackHistoryActive && !dynamicTriangleParameterHistoryActive
        if ownsTransaction { renderer.beginHistoryTransaction() }
        if renderer.setSelectedDynamicIsoscelesTriangleDegrees(d) {
            if ownsTransaction {
                renderer.endHistoryTransaction()
                notifyState()
                draw()
            } else {
                onSelectionChanged?()
                draw()
            }
        } else if ownsTransaction {
            renderer.endHistoryTransaction()
        }
    }
    func setSelectedDynamicIsoscelesTriangleLegLength(_ length: CGFloat) {
        let ownsTransaction = !dynamicTrianglePlaybackHistoryActive && !dynamicTriangleParameterHistoryActive
        if ownsTransaction { renderer.beginHistoryTransaction() }
        if renderer.setSelectedDynamicIsoscelesTriangleLegLength(length) {
            if ownsTransaction {
                renderer.endHistoryTransaction()
                notifyState()
                draw()
            } else {
                onSelectionChanged?()
                draw()
            }
        } else if ownsTransaction {
            renderer.endHistoryTransaction()
        }
    }
    func scaleSelected(by factor: Float) { renderer.beginHistoryTransaction(); renderer.scaleSelected(by: factor); renderer.endHistoryTransaction(); notifyState(); draw() }
    func reflectSelected(horizontal: Bool) { renderer.beginHistoryTransaction(); renderer.reflectSelected(horizontal: horizontal); renderer.endHistoryTransaction(); notifyState(); draw() }
    func setRotationCenterToSelectionCenter() { if let c = renderer.selectionCenter() { renderer.setRotationCenter(to: renderer.viewPoint(from: c)); onSelectionChanged?(); draw() } }
    func setRotationCenter(view point: SIMD2<Float>) { renderer.setRotationCenter(to: point); onSelectionChanged?(); draw() }
    func resetZoom() { renderer.resetZoom(centeredIn: bounds.size); onZoomChanged?(renderer.zoomPercent); draw() }
    func zoomIn() { renderer.zoom(by: 1.2, around: SIMD2(Float(bounds.midX), Float(bounds.midY))); onZoomChanged?(renderer.zoomPercent); draw() }
    func zoomOut() { renderer.zoom(by: 1 / 1.2, around: SIMD2(Float(bounds.midX), Float(bounds.midY))); onZoomChanged?(renderer.zoomPercent); draw() }
    private func notifyState() { onHistoryChanged?(); onSelectionChanged?(); onPageStateChanged?(renderer.exportPageState()) }
    private var selectionModeActive: Bool { isSelectionTool || temporarySelectHeld }

    private func copySelectionToPasteboard() {
        guard let data = renderer.makeSelectionClipboardData() else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: Self.mosuanClipboardType)
    }

    private func cutSelectionToPasteboard() {
        guard renderer.hasSelection, let data = renderer.makeSelectionClipboardData() else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setData(data, forType: Self.mosuanClipboardType) else { return }
        renderer.deleteSelected()
        notifyState()
        draw()
    }

    private func pasteSelectionFromPasteboard() {
        guard let data = NSPasteboard.general.data(forType: Self.mosuanClipboardType), renderer.pasteSelectionClipboardData(data) else { return }
        notifyState()
        draw()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let p = makePoint(from: event)
        if event.buttonNumber == 2 { middleButtonHeld = true; panDrag = true; lastPoint = p; return }
        if spaceHeld || isPanTool { panDrag = true; lastPoint = p; return }

        // Selection-tool hit targets must win over the generic "inside selection" drag.
        // When another tool is active, an existing selection owns the canvas so a stray click
        // cannot accidentally draw over the selected objects.
        if renderer.hasSelection && !temporarySelectHeld && !isSelectionTool {
            if let frame = renderer.selectionBoundsInView(), frame.contains(CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))) {
                selectionDrag = true
                lastPoint = p
                renderer.beginHistoryTransaction()
                return
            }
            renderer.clearSelection()
            onSelectionChanged?()
            draw()
            return
        }

        if isEraserTool && !temporarySelectHeld {
            renderer.beginHistoryTransaction()
            eraserPoints = [p]
            lastEraserPoint = p
            eraseAlongPath([p])
            return
        }
        if isDynamicAngleTool && !selectionModeActive {
            renderer.beginHistoryTransaction(); dynamicAngleDragID = renderer.commitDynamicAngle(at: p); active = true; lastPoint = p; onSelectionChanged?(); draw(); return
        }
        if isDynamicIsoscelesTriangleTool && !selectionModeActive {
            renderer.beginHistoryTransaction(); dynamicIsoscelesTriangleDragID = renderer.commitDynamicIsoscelesTriangle(at: p); active = true; lastPoint = p; onSelectionChanged?(); draw(); return
        }
        if isPolygonTool && !selectionModeActive { handlePolygonClick(at: p); return }
        guard !isPolygonTool else { return }
        if selectionModeActive {
            if let dynamicID = renderer.dynamicAngleEndpoint(at: p) { renderer.beginHistoryTransaction(); dynamicAngleDragID = dynamicID; return }
            if let triangleID = renderer.dynamicIsoscelesTriangleControlPoint(at: p) { renderer.beginHistoryTransaction(); dynamicIsoscelesTriangleDragID = triangleID; return }
            if let vertex = renderer.polygonVertex(at: p) { renderer.beginHistoryTransaction(); polygonVertexDrag = vertex; return }
            if let endpoint = renderer.lineEndpoint(at: p) { renderer.beginHistoryTransaction(); lineEndpointDrag = endpoint; return }
            if renderer.rotationCenterHandle(at: p) { renderer.beginHistoryTransaction(); rotationCenterDrag = true; return }
            if renderer.rotationHandle(at: p) { renderer.beginHistoryTransaction(); rotationDrag = true; lastRotationPoint = p; return }
            if let handle = renderer.selectionHandle(at: p) { renderer.beginHistoryTransaction(); resizeHandle = handle; return }
            if renderer.selectionMoveHandle(at: p) { renderer.beginHistoryTransaction(); selectionDrag = true; lastPoint = p; return }

            if renderer.hasSelection,
               let frame = renderer.selectionBoundsInView(),
               frame.contains(CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))) {
                renderer.beginHistoryTransaction()
                selectionDrag = true
                lastPoint = p
                return
            }

            let operation = SelectionOperation.fromModifiers(event.modifierFlags)
            renderer.beginHistoryTransaction()
            if renderer.selectObject(at: p, operation: operation) || renderer.selectStroke(at: p, operation: operation) { selectionDrag = true; lastPoint = p; onSelectionChanged?(); draw(); return }
            lassoActive = true; lassoOperation = operation; lassoPoints = [p]
            if operation == .replace { renderer.clearSelection() }
            lassoOverlay.update(points: lassoPoints, visible: true); onSelectionChanged?(); draw(); return
        }
        guard isUserInteractionEnabledForTool else { return }
        renderer.beginHistoryTransaction(); active = true; smartLineDetected = false; smartLineWorkItem?.cancel()
        let c = renderer.canvasPoint(from: p)
        points = [InkPoint(x: c.x, y: c.y, pressure: event.pressure > 0 ? Float(event.pressure) : 1)]
        renderer.setStroke(points); draw()
    }

    override func mouseDragged(with event: NSEvent) {
        let p = makePoint(from: event)
        if panDrag { renderer.pan(by: p - lastPoint); lastPoint = p; draw(); return }
        if isEraserTool && !temporarySelectHeld {
            eraserPoints.append(p)
            if let last = lastEraserPoint { eraseAlongPath([last, p]) } else { eraseAlongPath([p]) }
            lastEraserPoint = p
            return
        }
        if isDynamicAngleTool || dynamicAngleDragID != nil { if let id = dynamicAngleDragID { _ = renderer.moveDynamicAngleEndpoint(id: id, to: p); onSelectionChanged?(); draw(); return } }
        if isDynamicIsoscelesTriangleTool || dynamicIsoscelesTriangleDragID != nil { if let id = dynamicIsoscelesTriangleDragID { _ = renderer.moveDynamicIsoscelesTriangleControlPoint(id: id, to: p); onSelectionChanged?(); draw(); return } }
        if isPolygonTool { return }
        if selectionModeActive {
            if let vertex = polygonVertexDrag { _ = renderer.moveSelectedPolygonVertex(id: vertex.id, vertexIndex: vertex.vertexIndex, to: p); onSelectionChanged?(); draw(); return }
            if let endpoint = lineEndpointDrag { _ = renderer.moveSelectedLineEndpoint(id: endpoint.id, endpoint: endpoint.endpoint, to: p); onSelectionChanged?(); draw(); return }
            if rotationCenterDrag { renderer.setRotationCenter(to: p); onSelectionChanged?(); draw(); return }
            if rotationDrag { renderer.rotateSelected(to: p, from: lastRotationPoint); lastRotationPoint = p; onSelectionChanged?(); draw(); return }
            if let handle = resizeHandle { renderer.resizeSelected(handle: handle, to: p); onSelectionChanged?(); draw(); return }
            if lassoActive { appendLassoPoint(p); lassoOverlay.update(points: lassoPoints, visible: true); draw(); return }
            guard selectionDrag else { return }
            let delta = renderer.canvasPoint(from: p) - renderer.canvasPoint(from: lastPoint)
            if simd_length_squared(delta) > 0 { renderer.moveSelected(by: delta); lastPoint = p; onSelectionChanged?(); draw() }
            return
        }
        guard isUserInteractionEnabledForTool && active else { return }
        let c = renderer.canvasPoint(from: p)
        let pressure = event.pressure > 0 ? Float(event.pressure) : (points.last?.pressure ?? 1)
        points.append(InkPoint(x: c.x, y: c.y, pressure: pressure))
        renderer.setStroke((isLineTool || (isSmartLineTool && smartLineDetected)) ? linePreview(from: points) : points)
        scheduleSmartLineDetection(); draw()
    }

    override func mouseUp(with event: NSEvent) {
        smartLineWorkItem?.cancel()
        let p = makePoint(from: event)
        if event.buttonNumber == 2 || middleButtonHeld { middleButtonHeld = false; panDrag = false; return }
        if panDrag { panDrag = false; return }
        if isDynamicAngleTool || dynamicAngleDragID != nil { dynamicAngleDragID = nil; active = false; renderer.endHistoryTransaction(); notifyState(); draw(); return }
        if isDynamicIsoscelesTriangleTool || dynamicIsoscelesTriangleDragID != nil { dynamicIsoscelesTriangleDragID = nil; active = false; renderer.endHistoryTransaction(); notifyState(); draw(); return }
        if isPolygonTool { return }
        if isEraserTool && !temporarySelectHeld {
            eraserPoints.append(p)
            if let last = lastEraserPoint, simd_distance(last, p) > 0.001 { eraseAlongPath([last, p]) }
            lastEraserPoint = nil
            eraserPoints.removeAll(keepingCapacity: true)
            renderer.endHistoryTransaction()
            notifyState()
            draw()
            return
        }
        if selectionModeActive {
            if lassoActive {
                appendLassoPoint(p)
                let shouldSelect = lassoPoints.count >= 3 && lassoPathLength() >= 8
                if shouldSelect { _ = renderer.selectLasso(in: lassoPoints, operation: lassoOperation) } else if lassoOperation == .replace { renderer.clearSelection() }
                lassoActive = false; lassoPoints.removeAll(keepingCapacity: true); lassoOverlay.update(points: [], visible: false); renderer.endHistoryTransaction(); notifyState(); draw(); return
            }
            polygonVertexDrag = nil; lineEndpointDrag = nil; dynamicIsoscelesTriangleDragID = nil; rotationCenterDrag = false; rotationDrag = false; resizeHandle = nil; selectionDrag = false
            renderer.endHistoryTransaction(); notifyState(); draw(); return
        }
        guard isUserInteractionEnabledForTool && active else { return }
        let c = renderer.canvasPoint(from: p)
        let pressure = event.pressure > 0 ? Float(event.pressure) : (points.last?.pressure ?? 1)
        points.append(InkPoint(x: c.x, y: c.y, pressure: pressure))

        if isOneStrokeTool {
            switch OneStrokeRecognizer.recognize(points) {
            case .line(let start, let end):
                renderer.commitLine(from: SIMD2(Float(start.x), Float(start.y)), to: SIMD2(Float(end.x), Float(end.y)))
            case .polygon(let vertices):
                renderer.commitPolygon(points: vertices)
            case nil:
                renderer.commitStroke(points)
            }
        } else if isLineTool || (isSmartLineTool && smartLineDetected) {
            let line = linePreview(from: points)
            if line.count >= 2 { renderer.commitLine(from: SIMD2(line[0].x, line[0].y), to: SIMD2(line[1].x, line[1].y)) }
        } else {
            renderer.commitStroke(points)
        }
        renderer.endHistoryTransaction(); points.removeAll(keepingCapacity: true); active = false; smartLineDetected = false; renderer.setStroke([]); notifyState(); draw()
    }

    override func scrollWheel(with event: NSEvent) {
        let p = makePoint(from: event)
        if event.modifierFlags.contains(.command) { renderer.zoom(by: powf(1.0018, Float(event.scrollingDeltaY)), around: p); onZoomChanged?(renderer.zoomPercent); draw() } else { renderer.pan(by: SIMD2(Float(event.scrollingDeltaX), Float(event.scrollingDeltaY))); draw() }
    }

    override func keyDown(with event: NSEvent) {
        if event.isARepeat { return }
        if event.modifierFlags.contains(.command), let key = event.charactersIgnoringModifiers?.lowercased() {
            switch key { case "c": if renderer.hasSelection { copySelectionToPasteboard() }; return; case "x": cutSelectionToPasteboard(); return; case "v": pasteSelectionFromPasteboard(); return; default: break }
        }
        if event.keyCode == 53 && isPolygonTool && polygonModel.isConstructing { polygonModel.cancel(); renderer.setStroke([]); renderer.endHistoryTransaction(); draw(); return }
        if event.keyCode == 56 || event.keyCode == 60 { temporarySelectHeld = true; return }
        if event.keyCode == 49 { spaceHeld = true; return }
        if selectionModeActive && event.keyCode == 51 { deleteSelected(); return }
        if event.modifierFlags.contains(.command) && event.keyCode == 24 { zoomIn(); return }
        if event.modifierFlags.contains(.command) && event.keyCode == 27 { zoomOut(); return }
        if event.modifierFlags.contains(.command) && event.keyCode == 36 { resetZoom(); return }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == 56 || event.keyCode == 60 { temporarySelectHeld = false; return }
        if event.keyCode == 49 { spaceHeld = false; panDrag = false; return }
        super.keyUp(with: event)
    }

    override func tabletPoint(with event: NSEvent) {
        switch event.phase {
        case .began: mouseDown(with: event)
        case .changed: mouseDragged(with: event)
        case .ended: mouseUp(with: event)
        case .cancelled:
            smartLineWorkItem?.cancel(); active = false; points.removeAll(keepingCapacity: true); renderer.setStroke([])
            eraserPoints.removeAll(keepingCapacity: true); lastEraserPoint = nil
            if dynamicTrianglePlaybackHistoryActive { dynamicTrianglePlaybackHistoryActive = false; renderer.endHistoryTransaction() } else { renderer.endHistoryTransaction() }
            dynamicTriangleParameterHistoryActive = false; polygonModel.cancel(); polygonVertexDrag = nil; lineEndpointDrag = nil; dynamicAngleDragID = nil; dynamicIsoscelesTriangleDragID = nil; lassoActive = false; lassoPoints.removeAll(keepingCapacity: true); lassoOverlay.update(points: [], visible: false); draw()
        default: break
        }
    }

    private func handlePolygonClick(at viewPoint: SIMD2<Float>) {
        let canvas = renderer.canvasPoint(from: viewPoint); let point = CGPoint(x: CGFloat(canvas.x), y: CGFloat(canvas.y))
        if !polygonModel.isConstructing { polygonModel.begin(at: point); renderer.beginHistoryTransaction(); renderer.setStroke([InkPoint(x: canvas.x, y: canvas.y, pressure: 1)]); draw(); return }
        if polygonModel.closeIfNearFirst(at: point) { commitPolygon(polygonModel.previewVertices); polygonModel.cancel(); renderer.setStroke([]); renderer.endHistoryTransaction(); notifyState(); draw(); return }
        if polygonModel.append(at: point) { let preview = polygonModel.previewVertices.map { InkPoint(x: Float($0.x), y: Float($0.y), pressure: 1) }; renderer.setStroke(preview); draw() }
    }
    private func commitPolygon(_ vertices: [CGPoint]) { guard vertices.count >= 3 else { return }; renderer.commitPolygon(points: vertices) }
    private func appendLassoPoint(_ point: SIMD2<Float>) { guard let last = lassoPoints.last else { lassoPoints.append(point); return }; if simd_distance(last, point) >= 2 { lassoPoints.append(point) } }
    private func lassoPathLength() -> Float { guard lassoPoints.count >= 2 else { return 0 }; var total: Float = 0; for pair in zip(lassoPoints, lassoPoints.dropFirst()) { total += simd_distance(pair.0, pair.1) }; return total }
    private func scheduleSmartLineDetection() {
        guard isSmartLineTool, points.count >= 4 else { return }
        smartLineWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in guard let self, self.active, self.isSmartLineTool, self.points.count >= 4 else { return }; if LineGeometry.isLikelyStraight(points: self.points, tolerance: 8, minimumLength: 30) { self.smartLineDetected = true; self.renderer.setStroke(self.linePreview(from: self.points)); self.draw() } }
        smartLineWorkItem = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }
    private func linePreview(from p: [InkPoint]) -> [InkPoint] { guard let first = p.first, let last = p.last else { return p }; return [first, last] }
    private func eraseAlongPath(_ path: [SIMD2<Float>]) {
        guard !path.isEmpty else { return }
        var deleted = renderer.eraseObjectsByScribble(path, tolerance: 14)
        for p in path {
            if renderer.selectStroke(at: p, tolerance: 16) {
                renderer.deleteSelected()
                deleted = true
            }
        }
        if deleted { draw() }
    }
    private func makePoint(from event: NSEvent) -> SIMD2<Float> { let p = convert(event.locationInWindow, from: nil); return SIMD2(Float(p.x), Float(p.y)) }
}

private final class LassoOverlayView: NSView {
    private var points: [SIMD2<Float>] = []
    private var visible = false
    override var isFlipped: Bool { true }
    override init(frame frameRect: NSRect) { super.init(frame: frameRect); wantsLayer = true }
    required init?(coder: NSCoder) { super.init(coder: coder); wantsLayer = true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    func update(points: [SIMD2<Float>], visible: Bool) { self.points = points; self.visible = visible; isHidden = !visible; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        guard visible, points.count >= 2 else { return }
        let path = NSBezierPath(); path.move(to: NSPoint(x: CGFloat(points[0].x), y: CGFloat(points[0].y)))
        for point in points.dropFirst() { path.line(to: NSPoint(x: CGFloat(point.x), y: CGFloat(point.y))) }
        if points.count >= 3 { path.close() }
        path.lineWidth = 1.2; let dash: [CGFloat] = [5, 4]; path.setLineDash(dash, count: dash.count, phase: 0)
        NSColor.controlAccentColor.withAlphaComponent(0.9).setStroke(); NSColor.controlAccentColor.withAlphaComponent(0.06).setFill(); path.stroke(); path.fill()
    }
}
