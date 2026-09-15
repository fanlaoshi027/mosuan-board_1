import CoreGraphics
import Foundation

/// A named numeric parameter that can be shared by multiple geometry elements.
/// The value is always kept inside the configured range and aligned to the step.
struct GeometryParameter: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var value: CGFloat
    var minimum: CGFloat
    var maximum: CGFloat
    var step: CGFloat
    var isAnimatable: Bool
    var animationSpeed: CGFloat
    var animationLoop: GeometryParameterLoop

    init(
        id: UUID = UUID(),
        name: String,
        value: CGFloat,
        minimum: CGFloat = 1,
        maximum: CGFloat = 500,
        step: CGFloat = 1,
        isAnimatable: Bool = true,
        animationSpeed: CGFloat = 1,
        animationLoop: GeometryParameterLoop = .pingPong
    ) {
        self.id = id
        self.name = name
        self.minimum = min(minimum, maximum)
        self.maximum = max(minimum, maximum)
        self.step = max(0.0001, abs(step))
        self.value = Self.snap(value, minimum: self.minimum, maximum: self.maximum, step: self.step)
        self.isAnimatable = isAnimatable
        self.animationSpeed = max(0.01, animationSpeed)
        self.animationLoop = animationLoop
    }

    mutating func setValue(_ value: CGFloat) {
        self.value = Self.snap(value, minimum: minimum, maximum: maximum, step: step)
    }

    mutating func setRange(minimum: CGFloat, maximum: CGFloat, step: CGFloat) {
        self.minimum = min(minimum, maximum)
        self.maximum = max(minimum, maximum)
        self.step = max(0.0001, abs(step))
        value = Self.snap(value, minimum: self.minimum, maximum: self.maximum, step: self.step)
    }

    /// Advances the parameter by a signed amount. This is deliberately
    /// direction-aware so the same function can drive mouse scrubbing and animation.
    mutating func advance(by delta: CGFloat) {
        setValue(value + delta)
    }

    private static func snap(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat, step: CGFloat) -> CGFloat {
        let clamped = max(minimum, min(maximum, value))
        let index = ((clamped - minimum) / step).rounded()
        return max(minimum, min(maximum, minimum + index * step))
    }
}

enum GeometryParameterLoop: String, Codable, CaseIterable {
    /// Reverse at both ends. Preferred for teaching animations because there is no jump.
    case pingPong
    /// Restart at minimum after reaching maximum.
    case restart
}

/// Runtime state for driving a parameter without putting platform timers into the geometry core.
struct GeometryParameterAnimationState: Equatable {
    var isPlaying = false
    var direction: CGFloat = 1

    mutating func toggle() {
        isPlaying.toggle()
    }

    mutating func stop() {
        isPlaying = false
    }

    mutating func advance(parameter: inout GeometryParameter, deltaTime: CGFloat) {
        guard isPlaying, parameter.isAnimatable else { return }
        let delta = parameter.animationSpeed * max(0, deltaTime) * parameter.step * direction
        let next = parameter.value + delta

        switch parameter.animationLoop {
        case .pingPong:
            if next >= parameter.maximum {
                parameter.setValue(parameter.maximum)
                direction = -1
            } else if next <= parameter.minimum {
                parameter.setValue(parameter.minimum)
                direction = 1
            } else {
                parameter.setValue(next)
            }
        case .restart:
            if next >= parameter.maximum {
                parameter.setValue(parameter.minimum)
            } else {
                parameter.setValue(next)
            }
        }
    }
}

/// A length reference. A segment can either own a concrete length or reference
/// a shared named parameter, allowing multiple edges to stay synchronized.
enum GeometryLengthReference: Codable, Equatable {
    case fixed(CGFloat)
    case parameter(UUID)

    func resolved(using parameters: [GeometryParameter]) -> CGFloat? {
        switch self {
        case let .fixed(value):
            return max(0.0001, value)
        case let .parameter(id):
            return parameters.first(where: { $0.id == id })?.value
        }
    }
}

/// An angle can be concrete or driven by a shared named parameter.
enum GeometryAngleReference: Codable, Equatable {
    case fixed(CGFloat)
    case parameter(UUID)

    func resolved(using parameters: [GeometryParameter]) -> CGFloat? {
        switch self {
        case let .fixed(value):
            return max(0.001, min(179.999, value))
        case let .parameter(id):
            guard let value = parameters.first(where: { $0.id == id })?.value else { return nil }
            return max(0.001, min(179.999, value))
        }
    }
}
