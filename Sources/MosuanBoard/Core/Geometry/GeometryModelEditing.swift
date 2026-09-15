import CoreGraphics
import Foundation

/// Convenience editing APIs for wiring named parameters to geometry elements.
extension GeometryModel {
    mutating func bindAngle(_ angleID: UUID, to parameterID: UUID) -> Bool {
        guard parameters.contains(where: { $0.id == parameterID }),
              let index = angles.firstIndex(where: { $0.id == angleID }) else { return false }
        angles[index].angleReference = .parameter(parameterID)
        return true
    }

    mutating func setAngle(_ angleID: UUID, fixedDegrees: CGFloat) -> Bool {
        guard let index = angles.firstIndex(where: { $0.id == angleID }) else { return false }
        angles[index].angleReference = .fixed(fixedDegrees)
        return true
    }

    mutating func bindLength(_ lineID: UUID, to parameterID: UUID) -> Bool {
        guard parameters.contains(where: { $0.id == parameterID }),
              let index = lines.firstIndex(where: { $0.id == lineID }),
              lines[index].kind == .segment else { return false }
        lines[index].lengthReference = .parameter(parameterID)
        return true
    }

    mutating func setLength(_ lineID: UUID, fixedLength: CGFloat) -> Bool {
        guard let index = lines.firstIndex(where: { $0.id == lineID }),
              lines[index].kind == .segment else { return false }
        lines[index].lengthReference = .fixed(max(0.0001, fixedLength))
        return true
    }

    /// Changes a parameter and immediately resolves all dependent geometry.
    @discardableResult
    mutating func setParameterAndResolve(_ parameterID: UUID, value: CGFloat) -> Bool {
        guard parameters.contains(where: { $0.id == parameterID }) else { return false }
        setParameterValue(parameterID, value: value)
        GeometryConstraintSolver.apply(&self)
        return true
    }
}
