import AppKit
import PDFKit

struct PDFImportService {
    static func choosePDF() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func inspect(url: URL) -> PDFDocument? {
        guard let document = PDFKit.PDFDocument(url: url) else { return nil }
        return PDFDocument(filePath: url.path, fileName: url.lastPathComponent, pageCount: document.pageCount)
    }
}
