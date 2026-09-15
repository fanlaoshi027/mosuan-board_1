import Foundation

/// Shared style helpers for structured mathematical graphics.
enum GraphicObjectStyle {
    static func from(_ pen: PenStyle) -> GraphicObject.Style {
        GraphicObject.Style(
            strokeColor: pen.color,
            strokeWidth: pen.width,
            opacity: pen.opacity,
            lineStyle: pen.lineStyle,
            fillEnabled: false,
            fillColor: pen.color,
            fillOpacity: 0
        )
    }
}
