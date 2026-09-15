import AppKit

extension Notification.Name {
    static let mosuanShortcutAction = Notification.Name("mosuan.shortcutAction")
}

@MainActor
final class ShortcutEventMonitor {
    static let shared = ShortcutEventMonitor()

    private var monitor: Any?

    private init() {}

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard !Self.isTextEditingFirstResponder else { return event }
            guard !event.isARepeat else { return event }

            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

            // Command-Z must undo; Shift-Command-Z must redo.
            if flags == [.command, .shift] && key == "z" {
                NotificationCenter.default.post(name: .mosuanShortcutAction, object: "redo")
                return nil
            }
            if flags == .command && key == "z" {
                NotificationCenter.default.post(name: .mosuanShortcutAction, object: "undo")
                return nil
            }

            if flags.isEmpty {
                if event.keyCode == 48 { // Tab
                    NotificationCenter.default.post(name: .mosuanShortcutAction, object: "nextColor")
                    return nil
                }

                switch key {
                case "v": NotificationCenter.default.post(name: .mosuanShortcutAction, object: "select"); return nil
                case "p": NotificationCenter.default.post(name: .mosuanShortcutAction, object: "pen"); return nil
                case "l": NotificationCenter.default.post(name: .mosuanShortcutAction, object: "line"); return nil
                case "s": NotificationCenter.default.post(name: .mosuanShortcutAction, object: "smartLine"); return nil
                case "e": NotificationCenter.default.post(name: .mosuanShortcutAction, object: "eraser"); return nil
                case "h": NotificationCenter.default.post(name: .mosuanShortcutAction, object: "hand"); return nil
                default: break
                }
            }

            return event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private static var isTextEditingFirstResponder: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        return responder is NSTextField || responder is NSTextView || responder is NSSearchField
    }
}
