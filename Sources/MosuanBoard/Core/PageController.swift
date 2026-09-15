import Combine
import Foundation

@MainActor
final class PageController: ObservableObject {
    @Published private(set) var document: MosuanDocument

    init(document: MosuanDocument = MosuanDocument()) {
        self.document = document
    }

    var pages: [BoardPage] { document.pages }
    var currentIndex: Int { document.currentPageIndex }

    var currentPage: BoardPage? { document.currentPage }

    func selectPage(_ index: Int) {
        guard document.pages.indices.contains(index) else { return }
        document.currentPageIndex = index
    }

    func addPage() {
        document.addPage()
    }

    func duplicateCurrentPage() {
        document.duplicateCurrentPage()
    }

    func deleteCurrentPage() {
        document.deletePage(at: document.currentPageIndex)
    }

    func movePage(from source: Int, to destination: Int) {
        document.movePage(from: source, to: destination)
    }

    func renamePage(_ title: String, at index: Int) {
        guard document.pages.indices.contains(index) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        document.pages[index].title = trimmed.isEmpty ? "第 \(index + 1) 页" : trimmed
    }

    /// Called by the canvas whenever a real page mutation occurs.
    /// Keeping this at document level makes page switching lossless.
    func saveCurrentPageState(_ state: CanvasPageState) {
        document.updateCurrentPageContent(state)
    }

    func savePageState(_ state: CanvasPageState, at index: Int) {
        document.updatePageContent(state, at: index)
    }
}
