import CoreGraphics
import Foundation

struct PenStyle: Equatable, Codable {
    enum Tip: String, CaseIterable, Codable { case ballpoint, pencil, marker, highlighter }
    enum LineStyle: String, CaseIterable, Codable { case solid, dashed, dashDot, dotted }

    var color: RGBAColor = .black
    var width: CGFloat = 2.0
    var opacity: CGFloat = 1.0
    var tip: Tip = .ballpoint
    var lineStyle: LineStyle = .solid
    var pressureEnabled: Bool = true
    var pressureCurve: CGFloat = 1.0

    func width(for pressure: CGFloat) -> CGFloat {
        let p = max(0, min(1, pressure))
        guard pressureEnabled else { return width }
        let curved = pow(p, max(0.25, pressureCurve))
        return width * (0.45 + 0.75 * curved)
    }
}

struct RGBAColor: Equatable, Codable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    static let black = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let red = RGBAColor(red: 1, green: 0.08, blue: 0.08, alpha: 1)
    static let blue = RGBAColor(red: 0.08, green: 0.28, blue: 0.95, alpha: 1)
    static let green = RGBAColor(red: 0.08, green: 0.60, blue: 0.25, alpha: 1)
}

struct PenPreset: Identifiable, Equatable {
    let id: UUID
    var name: String
    var style: PenStyle

    init(id: UUID = UUID(), name: String, style: PenStyle) {
        self.id = id
        self.name = name
        self.style = style
    }

    static let defaults: [PenPreset] = [
        PenPreset(name: "黑色细笔", style: PenStyle(color: .black, width: 2.0)),
        PenPreset(name: "红色重点", style: PenStyle(color: .red, width: 2.5)),
        PenPreset(name: "蓝色书写", style: PenStyle(color: .blue, width: 2.0)),
        PenPreset(name: "绿色标记", style: PenStyle(color: .green, width: 2.5))
    ]
}
