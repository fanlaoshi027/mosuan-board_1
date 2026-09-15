import SwiftUI

struct PenCanvas: NSViewRepresentable {
    @Binding var tool: BoardTool

    func makeNSView(context: Context) -> InkMetalView {
        InkMetalView()
    }

    func updateNSView(_ nsView: InkMetalView, context: Context) {
        nsView.isUserInteractionEnabledForTool = (tool == .pen)
    }
}
