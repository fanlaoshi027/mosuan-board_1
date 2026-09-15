import SwiftUI

enum BoardInterfaceTheme: String, CaseIterable, Identifiable {
    case darkPurple
    case darkBlue
    case darkGreen
    case darkOrange
    case darkRed
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .darkPurple: "深紫"
        case .darkBlue: "深蓝"
        case .darkGreen: "深绿"
        case .darkOrange: "深橙"
        case .darkRed: "深红"
        case .light: "浅色"
        }
    }

    var systemImage: String {
        self == .light ? "sun.max.fill" : "circle.lefthalf.filled"
    }

    var colorScheme: ColorScheme {
        self == .light ? .light : .dark
    }

    var accent: Color {
        switch self {
        case .darkPurple: Color(red: 0.72, green: 0.18, blue: 0.95)
        case .darkBlue: Color(red: 0.25, green: 0.55, blue: 1.0)
        case .darkGreen: Color(red: 0.20, green: 0.82, blue: 0.48)
        case .darkOrange: Color(red: 1.0, green: 0.52, blue: 0.18)
        case .darkRed: Color(red: 1.0, green: 0.30, blue: 0.30)
        case .light: .accentColor
        }
    }
}