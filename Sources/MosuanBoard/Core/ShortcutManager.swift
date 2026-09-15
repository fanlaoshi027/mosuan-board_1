import AppKit
import SwiftUI

struct ShortcutBinding: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    var key: String
    var modifiers: NSEvent.ModifierFlags.RawValue

    var display: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.command) { parts.append("⌘") }
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        parts.append(key.uppercased())
        return parts.joined()
    }
}

@MainActor
final class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()
    private let defaultsKey = "mosuan.shortcuts"

    @Published private(set) var bindings: [ShortcutBinding]

    private init() {
        let defaults = [
            ShortcutBinding(id: "pan", title: "按住空格拖动画布", key: "space", modifiers: 0),
            ShortcutBinding(id: "nextColor", title: "切换画笔颜色", key: "tab", modifiers: 0),
            ShortcutBinding(id: "undo", title: "撤销", key: "z", modifiers: NSEvent.ModifierFlags.command.rawValue),
            ShortcutBinding(id: "redo", title: "重做", key: "z", modifiers: (NSEvent.ModifierFlags.command.union(.shift)).rawValue),
            ShortcutBinding(id: "select", title: "选择工具", key: "v", modifiers: 0),
            ShortcutBinding(id: "pen", title: "画笔工具", key: "p", modifiers: 0),
            ShortcutBinding(id: "line", title: "直线工具", key: "l", modifiers: 0),
            ShortcutBinding(id: "smartLine", title: "智能直线", key: "s", modifiers: 0),
            ShortcutBinding(id: "eraser", title: "橡皮工具", key: "e", modifiers: 0)
        ]
        if let data = UserDefaults.standard.data(forKey: defaultsKey), let saved = try? JSONDecoder().decode([ShortcutBinding].self, from: data) {
            bindings = saved
        } else {
            bindings = defaults
        }
    }

    func binding(_ id: String) -> ShortcutBinding? { bindings.first { $0.id == id } }

    func update(id: String, key: String, modifiers: NSEvent.ModifierFlags) {
        guard let index = bindings.firstIndex(where: { $0.id == id }) else { return }
        bindings[index].key = key.lowercased()
        bindings[index].modifiers = modifiers.rawValue
        save()
    }

    func resetDefaults() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        bindings = [
            ShortcutBinding(id: "pan", title: "按住空格拖动画布", key: "space", modifiers: 0),
            ShortcutBinding(id: "nextColor", title: "切换画笔颜色", key: "tab", modifiers: 0),
            ShortcutBinding(id: "undo", title: "撤销", key: "z", modifiers: NSEvent.ModifierFlags.command.rawValue),
            ShortcutBinding(id: "redo", title: "重做", key: "z", modifiers: (NSEvent.ModifierFlags.command.union(.shift)).rawValue),
            ShortcutBinding(id: "select", title: "选择工具", key: "v", modifiers: 0),
            ShortcutBinding(id: "pen", title: "画笔工具", key: "p", modifiers: 0),
            ShortcutBinding(id: "line", title: "直线工具", key: "l", modifiers: 0),
            ShortcutBinding(id: "smartLine", title: "智能直线", key: "s", modifiers: 0),
            ShortcutBinding(id: "eraser", title: "橡皮工具", key: "e", modifiers: 0)
        ]
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bindings) { UserDefaults.standard.set(data, forKey: defaultsKey) }
    }
}
