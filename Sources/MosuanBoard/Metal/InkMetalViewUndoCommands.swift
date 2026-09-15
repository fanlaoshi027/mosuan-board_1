import AppKit

// Exposes the canvas history actions through the standard AppKit responder chain.
// InkMetalView already handles the actual history state; these selectors let
// Command-Z / Command-Shift-Z reach the view without duplicating history logic.
extension InkMetalView {
    @objc func undo(_ sender: Any?) {
        undo()
    }

    @objc func redo(_ sender: Any?) {
        redo()
    }
}
