import Foundation

/// Resolves the SwiftPM resource bundle from the packaged .app.
/// Bundle.module can trap when the executable is repackaged manually,
/// so runtime code uses this explicit lookup instead.
enum MosuanResourceBundle {
    static var bundle: Bundle? {
        let name = "MosuanBoard_MosuanBoard"

        if let url = Bundle.main.url(forResource: name, withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }

        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("\(name).bundle", isDirectory: true)

        return Bundle(url: url)
    }
}
