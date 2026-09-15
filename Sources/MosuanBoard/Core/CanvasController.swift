import Combine
import CoreGraphics

final class CanvasController: ObservableObject {
    weak var canvas: InkMetalView?
    private let dynamicTrianglePlayback = DynamicIsoscelesTrianglePlaybackController()

    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var hasSelection = false
    @Published private(set) var selectionCount = 0
    @Published private(set) var rotationDegrees: Double = 0
    @Published private(set) var selectionFrame: CGRect = .zero
    @Published private(set) var dynamicAngleDegrees: Double?
    @Published private(set) var dynamicAnglePlaying = false
    @Published private(set) var dynamicTriangleDegrees: Double?
    @Published private(set) var dynamicTriangleLegLength: Double?

    deinit { dynamicTrianglePlayback.stop() }

    func attach(_ canvas: InkMetalView) {
        // SwiftUI's updateNSView can run repeatedly for ordinary state changes.
        // Re-attaching the same canvas used to call refreshState(), which publishes
        // @Published values during updateNSView and created a feedback loop.
        if self.canvas === canvas { return }

        dynamicTrianglePlayback.stop()
        self.canvas = canvas
        canvas.onHistoryChanged = { [weak self, weak canvas] in
            guard let self, let canvas else { return }
            self.canUndo = canvas.canUndo
            self.canRedo = canvas.canRedo
        }
        canvas.onSelectionChanged = { [weak self, weak canvas] in
            guard let self, let canvas else { return }
            self.hasSelection = canvas.hasSelection
            self.selectionCount = canvas.selectionCount
            self.rotationDegrees = canvas.selectedRotationDegrees
            self.selectionFrame = canvas.selectionBoundsInView ?? .zero
            self.dynamicAngleDegrees = canvas.selectedDynamicAngleDegrees.map(Double.init)
            self.dynamicAnglePlaying = canvas.isSelectedDynamicAnglePlaying
            self.dynamicTriangleDegrees = canvas.selectedDynamicIsoscelesTriangleDegrees.map(Double.init)
            self.dynamicTriangleLegLength = canvas.selectedDynamicIsoscelesTriangleLegLength.map(Double.init)
        }
        refreshState()
    }

    func undo() {
        dynamicTrianglePlayback.stop()
        canvas?.stopDynamicAnglePlayback()
        canvas?.endDynamicTrianglePlaybackHistory()
        canvas?.endDynamicTriangleParameterEditHistory()
        canvas?.undo()
        refreshState()
    }

    func redo() {
        dynamicTrianglePlayback.stop()
        canvas?.stopDynamicAnglePlayback()
        canvas?.endDynamicTrianglePlaybackHistory()
        canvas?.endDynamicTriangleParameterEditHistory()
        canvas?.redo()
        refreshState()
    }

    func deleteSelected() {
        dynamicTrianglePlayback.stop()
        canvas?.stopDynamicAnglePlayback()
        canvas?.endDynamicTrianglePlaybackHistory()
        canvas?.endDynamicTriangleParameterEditHistory()
        canvas?.deleteSelected()
        refreshState()
    }

    func setRotationDegrees(_ d: Double) { canvas?.setSelectedRotationDegrees(d); refreshState() }
    func scaleSelected(by f: Float) { canvas?.scaleSelected(by: f); refreshState() }
    func reflectHorizontal() { canvas?.reflectSelected(horizontal: true); refreshState() }
    func reflectVertical() { canvas?.reflectSelected(horizontal: false); refreshState() }
    func resetRotationCenter() { canvas?.setRotationCenterToSelectionCenter(); refreshState() }

    func setDynamicAngleDegrees(_ degrees: Double) {
        guard !dynamicAnglePlaying else { return }
        canvas?.setSelectedDynamicAngleDegrees(CGFloat(degrees))
        refreshState()
    }

    func toggleDynamicAnglePlayback() {
        canvas?.toggleSelectedDynamicAnglePlayback()
        refreshState()
    }

    func setDynamicTriangleDegrees(_ degrees: Double) {
        guard !dynamicTrianglePlayback.isPlaying else { return }
        canvas?.setSelectedDynamicIsoscelesTriangleDegrees(CGFloat(degrees))
        refreshState()
    }

    func setDynamicTriangleLegLength(_ length: Double) {
        guard !dynamicTrianglePlayback.isPlaying else { return }
        canvas?.setSelectedDynamicIsoscelesTriangleLegLength(CGFloat(length))
        refreshState()
    }

    func beginDynamicTriangleParameterEditHistory() {
        guard !dynamicTrianglePlayback.isPlaying else { return }
        canvas?.beginDynamicTriangleParameterEditHistory()
    }

    func endDynamicTriangleParameterEditHistory() {
        canvas?.endDynamicTriangleParameterEditHistory()
        refreshState()
    }

    func beginDynamicTrianglePlaybackHistory() {
        guard !dynamicTrianglePlayback.isPlaying else { return }
        guard let canvas, let initialAngle = canvas.selectedDynamicIsoscelesTriangleDegrees else {
            refreshState()
            return
        }
        canvas.beginDynamicTrianglePlaybackHistory()
        dynamicTrianglePlayback.start(currentAngle: initialAngle) { [weak self] degrees in
            guard let self else { return }
            self.canvas?.setSelectedDynamicIsoscelesTriangleDegrees(degrees)
            self.refreshState()
        }
        refreshState()
    }

    func endDynamicTrianglePlaybackHistory() {
        dynamicTrianglePlayback.stop()
        canvas?.endDynamicTrianglePlaybackHistory()
        refreshState()
    }

    func refreshState() {
        canUndo = canvas?.canUndo ?? false
        canRedo = canvas?.canRedo ?? false
        hasSelection = canvas?.hasSelection ?? false
        selectionCount = canvas?.selectionCount ?? 0
        rotationDegrees = canvas?.selectedRotationDegrees ?? 0
        selectionFrame = canvas?.selectionBoundsInView ?? .zero
        dynamicAngleDegrees = canvas?.selectedDynamicAngleDegrees.map(Double.init)
        dynamicAnglePlaying = canvas?.isSelectedDynamicAnglePlaying ?? false
        dynamicTriangleDegrees = canvas?.selectedDynamicIsoscelesTriangleDegrees.map(Double.init)
        dynamicTriangleLegLength = canvas?.selectedDynamicIsoscelesTriangleLegLength.map(Double.init)
    }
}