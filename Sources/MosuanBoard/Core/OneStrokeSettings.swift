import Foundation

/// Shared, platform-independent settings for one-stroke shape conversion.
/// Platform UI layers can bind their switches directly to this value later.
struct OneStrokeSettings: Equatable, Codable {
    enum Sensitivity: String, CaseIterable, Codable {
        case low
        case standard
        case high

        var recognizerConfiguration: OneStrokeShapeRecognizer.Configuration {
            switch self {
            case .low:
                var configuration = OneStrokeShapeRecognizer.Configuration()
                configuration.enabled = true
                configuration.minimumPoints = 10
                configuration.closedDistanceRatio = 0.13
                configuration.lineStraightness = 0.992
                configuration.shapeFitTolerance = 0.09
                return configuration
            case .standard:
                return OneStrokeShapeRecognizer.Configuration()
            case .high:
                var configuration = OneStrokeShapeRecognizer.Configuration()
                configuration.enabled = true
                configuration.minimumPoints = 6
                configuration.closedDistanceRatio = 0.20
                configuration.lineStraightness = 0.975
                configuration.shapeFitTolerance = 0.16
                return configuration
            }
        }
    }

    /// Global switch shared by macOS, iPadOS, Windows and iPhone.
    var oneStrokeEnabled: Bool = true
    var sensitivity: Sensitivity = .standard
}

/// A single completed stroke is converted at commit time only.
/// Predicted points must never be passed here.
struct OneStrokeCommitter {
    var settings = OneStrokeSettings()

    func commit(
        points: [CGPoint],
        style: GraphicObject.Style
    ) -> GraphicObject? {
        guard settings.oneStrokeEnabled else { return nil }

        var recognizer = OneStrokeShapeRecognizer()
        recognizer.configuration = settings.sensitivity.recognizerConfiguration

        guard let result = recognizer.recognize(points: points), result.isConfident else {
            return nil
        }
        return recognizer.makeGraphicObject(from: result, style: style)
    }
}
