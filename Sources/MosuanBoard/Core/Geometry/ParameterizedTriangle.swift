import CoreGraphics
import Foundation

enum TriangleKind: String, Codable, CaseIterable {
    case arbitrary
    case isosceles
    case equilateral
    case right
}

/// A triangle driven by geometric parameters rather than a fixed bitmap.
/// For an isosceles triangle, base length, equal-leg length and apex angle are
/// kept mathematically consistent according to whichever parameters are unlocked.
struct ParameterizedTriangle: Codable, Equatable, Identifiable {
    let id: UUID
    var kind: TriangleKind
    var anchor: CGPoint
    var rotation: CGFloat
    var baseLength: CGFloat
    var legLength: CGFloat
    var apexAngleDegrees: CGFloat
    var lockedBaseLength: Bool
    var lockedLegLength: Bool
    var lockedApexAngle: Bool
    var anchorPointName: String?

    init(
        id: UUID = UUID(),
        kind: TriangleKind = .isosceles,
        anchor: CGPoint = .zero,
        rotation: CGFloat = 0,
        baseLength: CGFloat = 160,
        legLength: CGFloat = 120,
        apexAngleDegrees: CGFloat = 60,
        lockedBaseLength: Bool = false,
        lockedLegLength: Bool = false,
        lockedApexAngle: Bool = false,
        anchorPointName: String? = "A"
    ) {
        self.id = id
        self.kind = kind
        self.anchor = anchor
        self.rotation = rotation
        self.baseLength = max(1, baseLength)
        self.legLength = max(1, legLength)
        self.apexAngleDegrees = Self.clampAngle(apexAngleDegrees)
        self.lockedBaseLength = lockedBaseLength
        self.lockedLegLength = lockedLegLength
        self.lockedApexAngle = lockedApexAngle
        self.anchorPointName = anchorPointName
    }

    /// Returns A, B, C in canvas coordinates. A is the anchored vertex.
    func vertices() -> [CGPoint] {
        let angle = Self.clampAngle(apexAngleDegrees) * .pi / 180
        let leg = max(1, legLength)
        let halfBase = leg * sin(angle / 2)
        let height = leg * cos(angle / 2)

        let localA = CGPoint.zero
        let localB = CGPoint(x: -halfBase, y: height)
        let localC = CGPoint(x: halfBase, y: height)
        return [localA, rotate(localB), rotate(localC)].map {
            CGPoint(x: $0.x + anchor.x, y: $0.y + anchor.y)
        }
    }

    /// Position of the orange apex-angle control point.
    func angleControlPoint(radius: CGFloat = 58) -> CGPoint {
        let r = max(8, radius)
        let c = cos(rotation)
        let s = sin(rotation)
        return CGPoint(
            x: anchor.x - r * s,
            y: anchor.y + r * c
        )
    }

    /// Position of the direct equal-leg length control point.
    /// It sits halfway along AB, so dragging it along the AB ray changes only
    /// the leg length while preserving the apex angle and AB = AC constraint.
    func legLengthControlPoint() -> CGPoint {
        let points = vertices()
        guard points.count >= 2 else { return anchor }
        return CGPoint(
            x: (points[0].x + points[1].x) * 0.5,
            y: (points[0].y + points[1].y) * 0.5
        )
    }

    /// Converts a dragged point on the AB ray into the corresponding leg length.
    /// The anchor remains fixed; the current apex angle and equal-leg constraint remain intact.
    func legLength(forControlPoint point: CGPoint) -> CGFloat? {
        let dx = point.x - anchor.x
        let dy = point.y - anchor.y
        let distance = hypot(dx, dy)
        guard distance > 0.001 else { return nil }
        return max(1, distance * 2)
    }

    mutating func setApexAngle(_ degrees: CGFloat) {
        guard !lockedApexAngle else { return }
        let newAngle = Self.clampAngle(degrees)

        switch kind {
        case .equilateral:
            apexAngleDegrees = 60
            legLength = max(1, baseLength)
        case .isosceles:
            if lockedBaseLength && lockedLegLength {
                apexAngleDegrees = Self.angleFor(base: baseLength, leg: legLength)
            } else if lockedBaseLength {
                apexAngleDegrees = newAngle
                legLength = Self.legFor(base: baseLength, angleDegrees: newAngle)
            } else {
                apexAngleDegrees = newAngle
                baseLength = Self.baseFor(leg: legLength, angleDegrees: newAngle)
            }
        default:
            apexAngleDegrees = newAngle
        }
    }

    mutating func setLegLength(_ length: CGFloat) {
        guard !lockedLegLength else { return }
        let newLeg = max(1, length)

        switch kind {
        case .equilateral:
            legLength = newLeg
            baseLength = newLeg
            apexAngleDegrees = 60
        case .isosceles:
            if lockedBaseLength {
                legLength = max(newLeg, baseLength / 2)
                if !lockedApexAngle {
                    apexAngleDegrees = Self.angleFor(base: baseLength, leg: legLength)
                }
            } else {
                legLength = newLeg
                baseLength = Self.baseFor(leg: legLength, angleDegrees: apexAngleDegrees)
            }
        default:
            legLength = newLeg
        }
    }

    mutating func setBaseLength(_ length: CGFloat) {
        guard !lockedBaseLength else { return }
        let newBase = max(1, length)

        switch kind {
        case .equilateral:
            baseLength = newBase
            legLength = newBase
            apexAngleDegrees = 60
        case .isosceles:
            if lockedLegLength {
                baseLength = min(newBase, 2 * legLength - 0.001)
                if !lockedApexAngle {
                    apexAngleDegrees = Self.angleFor(base: baseLength, leg: legLength)
                }
            } else {
                baseLength = newBase
                legLength = Self.legFor(base: baseLength, angleDegrees: apexAngleDegrees)
            }
        default:
            baseLength = newBase
        }
    }

    mutating func setRotation(_ radians: CGFloat) {
        rotation = radians
    }

    /// Normalizes an isosceles triangle after loading or changing its type.
    mutating func normalize() {
        switch kind {
        case .equilateral:
            apexAngleDegrees = 60
            if lockedBaseLength {
                legLength = baseLength
            } else if lockedLegLength {
                baseLength = legLength
            } else {
                baseLength = max(1, baseLength)
                legLength = baseLength
            }
        case .isosceles:
            if lockedBaseLength && lockedLegLength {
                apexAngleDegrees = Self.angleFor(base: baseLength, leg: legLength)
            } else if lockedBaseLength {
                legLength = Self.legFor(base: baseLength, angleDegrees: apexAngleDegrees)
            } else {
                baseLength = Self.baseFor(leg: legLength, angleDegrees: apexAngleDegrees)
            }
        default:
            break
        }
    }

    private static func clampAngle(_ degrees: CGFloat) -> CGFloat {
        max(1, min(179, degrees))
    }

    private static func baseFor(leg: CGFloat, angleDegrees: CGFloat) -> CGFloat {
        let angle = clampAngle(angleDegrees) * .pi / 180
        return max(1, 2 * max(1, leg) * sin(angle / 2))
    }

    private static func legFor(base: CGFloat, angleDegrees: CGFloat) -> CGFloat {
        let angle = clampAngle(angleDegrees) * .pi / 180
        return max(1, (max(1, base) / 2) / max(sin(angle / 2), 0.0001))
    }

    private static func angleFor(base: CGFloat, leg: CGFloat) -> CGFloat {
        let ratio = max(0.0001, min(1, max(1, base) / (2 * max(1, leg))))
        return clampAngle(2 * asin(ratio) * 180 / .pi)
    }

    private func rotate(_ point: CGPoint) -> CGPoint {
        let c = cos(rotation), s = sin(rotation)
        return CGPoint(x: point.x * c - point.y * s,
                       y: point.x * s + point.y * c)
    }
}
