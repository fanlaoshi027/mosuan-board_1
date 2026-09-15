import Foundation

struct RGBAColor: Equatable, Codable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat
    static let black = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
}

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

struct PenPreset: Identifiable {
    let id: String
    let name: String
    let style: PenStyle
    static let defaults: [PenPreset] = [
        PenPreset(id: "black", name: "黑", style: PenStyle()),
        PenPreset(id: "red", name: "红", style: PenStyle(color: RGBAColor(red: 0.95, green: 0.12, blue: 0.12, alpha: 1))),
        PenPreset(id: "blue", name: "蓝", style: PenStyle(color: RGBAColor(red: 0.12, green: 0.38, blue: 0.95, alpha: 1))),
        PenPreset(id: "green", name: "绿", style: PenStyle(color: RGBAColor(red: 0.10, green: 0.65, blue: 0.25, alpha: 1)))
    ]
}
