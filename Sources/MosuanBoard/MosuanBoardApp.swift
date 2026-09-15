import SwiftUI

@main
struct MosuanBoardApp: App {
    @NSApplicationDelegateAdaptor(MosuanStartupDelegate.self) private var startupDelegate

    var body: some Scene {
        WindowGroup("Mosuan Board") {
            ZStack {
                BoardScreen()
                DynamicAngleOverlay()
            }
            .frame(minWidth: 1100, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
