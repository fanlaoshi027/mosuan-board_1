import Foundation

/// One page in a Mosuan document.
/// Page metadata and its actual canvas content travel together so switching pages never
/// loses strokes or structured graphic objects.
struct BoardPage: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var width: Double
    var height: Double
    var background: String
    var pattern: Int
    var content: CanvasPageState

    init(
        id: UUID = UUID(),
        title: String = "第 1 页",
        width: Double = 1280,
        height: Double = 720,
        background: String = "white",
        pattern: Int = 0,
        content: CanvasPageState = CanvasPageState()
    ) {
        self.id = id
        self.title = title
        self.width = width
        self.height = height
        self.background = background
        self.pattern = pattern
        self.content = content
    }
}

/// Document-level page container. This is intentionally platform-independent so the same
/// model can later be used by macOS, iPadOS and Windows implementations.
struct MosuanDocument: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var pages: [BoardPage]
    var currentPageIndex: Int
    var version: Int

    init(
        id: UUID = UUID(),
        title: String = "未命名文档",
        pages: [BoardPage] = [BoardPage()],
        currentPageIndex: Int = 0,
        version: Int = 1
    ) {
        self.id = id
        self.title = title
        self.pages = pages.isEmpty ? [BoardPage()] : pages
        self.currentPageIndex = min(max(currentPageIndex, 0), max(self.pages.count - 1, 0))
        self.version = version
    }

    var currentPage: BoardPage? {
        guard pages.indices.contains(currentPageIndex) else { return nil }
        return pages[currentPageIndex]
    }

    mutating func addPage(after index: Int? = nil, template: BoardPage? = nil) {
        let source = template ?? currentPage ?? BoardPage()
        let page = BoardPage(
            title: "第 \(pages.count + 1) 页",
            width: source.width,
            height: source.height,
            background: source.background,
            pattern: source.pattern,
            content: template == nil ? CanvasPageState() : source.content
        )
        let insertionIndex = min(max((index ?? currentPageIndex) + 1, 0), pages.count)
        pages.insert(page, at: insertionIndex)
        currentPageIndex = insertionIndex
        renumberUntitledPages()
    }

    mutating func duplicateCurrentPage() {
        guard let source = currentPage else { return }
        addPage(after: currentPageIndex, template: source)
    }

    mutating func deletePage(at index: Int) {
        guard pages.count > 1, pages.indices.contains(index) else { return }
        pages.remove(at: index)
        currentPageIndex = min(currentPageIndex, pages.count - 1)
        renumberUntitledPages()
    }

    mutating func movePage(from source: Int, to destination: Int) {
        guard pages.indices.contains(source), pages.indices.contains(destination), source != destination else { return }
        let page = pages.remove(at: source)
        pages.insert(page, at: destination)
        if currentPageIndex == source {
            currentPageIndex = destination
        } else if source < currentPageIndex && destination >= currentPageIndex {
            currentPageIndex -= 1
        } else if source > currentPageIndex && destination <= currentPageIndex {
            currentPageIndex += 1
        }
    }

    mutating func updateCurrentPageContent(_ content: CanvasPageState) {
        guard pages.indices.contains(currentPageIndex) else { return }
        pages[currentPageIndex].content = content
    }

    mutating func updatePageContent(_ content: CanvasPageState, at index: Int) {
        guard pages.indices.contains(index) else { return }
        pages[index].content = content
    }

    mutating func updateCurrentPageAppearance(background: String, pattern: Int) {
        guard pages.indices.contains(currentPageIndex) else { return }
        pages[currentPageIndex].background = background
        pages[currentPageIndex].pattern = pattern
    }

    private mutating func renumberUntitledPages() {
        for index in pages.indices where pages[index].title.hasPrefix("第 ") {
            pages[index].title = "第 \(index + 1) 页"
        }
    }
}
