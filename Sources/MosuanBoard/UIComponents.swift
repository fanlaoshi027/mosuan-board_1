import SwiftUI
import AppKit

/// Shared board UI types used by the current macOS screen.
enum BoardTool: Equatable { case select, pen, line, smartLine, polygon, oneStroke, dynamicAngle, dynamicIsoscelesTriangle, eraser, hand }

enum BoardBackground: String, CaseIterable, Identifiable {
    case white, black, darkGray, lightGray, cream
    var id: String { rawValue }
    var title: String { switch self { case .white: "白色"; case .black: "黑色"; case .darkGray: "深灰"; case .lightGray: "浅灰"; case .cream: "米白" } }
    var color: Color { switch self { case .white: .white; case .black: .black; case .darkGray: Color(white: 0.18); case .lightGray: Color(white: 0.92); case .cream: Color(red: 0.98, green: 0.96, blue: 0.88) } }
    var metal: SIMD4<Float> { switch self { case .white: SIMD4(1,1,1,1); case .black: SIMD4(0,0,0,1); case .darkGray: SIMD4(0.18,0.18,0.18,1); case .lightGray: SIMD4(0.92,0.92,0.92,1); case .cream: SIMD4(0.98,0.96,0.88,1) } }
}

enum BoardPattern: Int, CaseIterable, Identifiable {
    case blank = 0, ruled = 1, grid = 2, dots = 3, mathGrid = 4
    var id: Int { rawValue }
    var title: String { switch self { case .blank: "空白"; case .ruled: "横线"; case .grid: "方格"; case .dots: "点阵"; case .mathGrid: "数学方格" } }
}

enum EyeComfortBackground: String, CaseIterable, Identifiable {
    case black90, deepGreen, deepBlue, custom
    var id: String { rawValue }
    var title: String { switch self { case .black90: "90%黑"; case .deepGreen: "深绿"; case .deepBlue: "深蓝"; case .custom: "自定义色值" } }
    var color: SIMD4<Float> { switch self { case .black90: SIMD4(0.10,0.10,0.10,1); case .deepGreen: SIMD4(0.08,0.16,0.12,1); case .deepBlue: SIMD4(0.07,0.12,0.22,1); case .custom: SIMD4(0.10,0.10,0.10,1) } }
}

struct ToolButton: View {
    let title: String
    let systemImage: String
    let selected: Bool
    let action: () -> Void
    var body: some View { Button(action: action) { Label(title, systemImage: systemImage).padding(.horizontal, 8) }.buttonStyle(.bordered).tint(selected ? .accentColor : .secondary) }
}

struct PageSidebar: View {
    @ObservedObject var controller: PageController
    var body: some View {
        VStack(spacing: 10) {
            HStack { Text("页面").font(.headline); Spacer(); Button { controller.addPage() } label: { Image(systemName: "plus") }.buttonStyle(.borderless) }.padding(.horizontal, 10).padding(.top, 10)
            ScrollView { LazyVStack(spacing: 8) { ForEach(Array(controller.pages.enumerated()), id: \.element.id) { index, page in Button { controller.selectPage(index) } label: { VStack(spacing: 4) { RoundedRectangle(cornerRadius: 5).fill(pagePreviewColor(page.background)).overlay { RoundedRectangle(cornerRadius: 5).stroke(controller.currentIndex == index ? Color.accentColor : Color.gray.opacity(0.25), lineWidth: controller.currentIndex == index ? 2 : 1) }.overlay { Text("第 \(index + 1) 页").font(.system(size: 11, weight: .medium)).foregroundStyle(page.background == "black" ? .white : .primary) }.frame(width: 120, height: 76); Text(page.title).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1) }.frame(width: 128) }.buttonStyle(.plain) } }.padding(.horizontal, 8) }
            Spacer()
            HStack { Button { controller.duplicateCurrentPage() } label: { Image(systemName: "plus.square.on.square") }; Button(role: .destructive) { controller.deleteCurrentPage() } label: { Image(systemName: "trash") } }.padding(.bottom, 10)
        }.frame(width: 145)
    }
    private func pagePreviewColor(_ value: String) -> Color { switch value { case "black": .black; case "darkGray": Color(white: 0.18); case "lightGray": Color(white: 0.92); case "cream": Color(red: 0.98, green: 0.96, blue: 0.88); default: .white } }
}

struct MetalInkCanvas: NSViewRepresentable {
    var pageState: CanvasPageState?
    @Binding var tool: BoardTool
    let penStyle: PenStyle
    @ObservedObject var controller: CanvasController
    var background: SIMD4<Float> = SIMD4(1,1,1,1)
    var inverted = false
    var pattern: BoardPattern = .blank
    @Binding var zoomPercent: Int
    var onPageStateChanged: ((CanvasPageState) -> Void)?

    init(pageState: CanvasPageState? = nil,
         tool: Binding<BoardTool>,
         penStyle: PenStyle,
         controller: CanvasController,
         background: SIMD4<Float> = SIMD4(1,1,1,1),
         inverted: Bool = false,
         pattern: BoardPattern = .blank,
         zoomPercent: Binding<Int>,
         onPageStateChanged: ((CanvasPageState) -> Void)? = nil) {
        self.pageState = pageState
        self._tool = tool
        self.penStyle = penStyle
        self.controller = controller
        self.background = background
        self.inverted = inverted
        self.pattern = pattern
        self._zoomPercent = zoomPercent
        self.onPageStateChanged = onPageStateChanged
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> InkMetalView {
        let view = InkMetalView()
        configure(view)
        view.onPageStateChanged = onPageStateChanged
        view.onZoomChanged = { value in zoomPercent = value }
        if let pageState { view.loadPageState(pageState) }
        controller.attach(view)
        return view
    }
    func updateNSView(_ view: InkMetalView, context: Context) {
        configure(view)
        view.onPageStateChanged = onPageStateChanged
        view.onZoomChanged = { value in zoomPercent = value }
        if let pageState { view.loadPageState(pageState) }
        controller.attach(view)
    }
    private func configure(_ view: InkMetalView) {
        view.isUserInteractionEnabledForTool = tool == .pen || tool == .line || tool == .smartLine || tool == .polygon || tool == .oneStroke || tool == .dynamicAngle || tool == .dynamicIsoscelesTriangle
        view.isSelectionTool = tool == .select
        view.isPanTool = tool == .hand
        view.isLineTool = tool == .line
        view.isSmartLineTool = tool == .smartLine
        view.isPolygonTool = tool == .polygon
        view.isOneStrokeTool = tool == .oneStroke
        view.isDynamicAngleTool = tool == .dynamicAngle
        view.isDynamicIsoscelesTriangleTool = tool == .dynamicIsoscelesTriangle
        view.isEraserTool = tool == .eraser
        view.penStyle = penStyle
        view.boardBackground = background
        view.displayInverted = inverted
        view.backgroundPattern = pattern.rawValue
    }
    final class Coordinator { }
}
