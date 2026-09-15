import CoreGraphics

// Lower-priority bridges used only when an expression intentionally mixes
// Metal Float geometry with CoreGraphics CGFloat geometry.
@_disfavoredOverload
@inline(__always)
func * (lhs: Float, rhs: CGFloat) -> CGFloat {
    CGFloat(lhs) * rhs
}

@_disfavoredOverload
@inline(__always)
func / (lhs: Float, rhs: CGFloat) -> CGFloat {
    CGFloat(lhs) / rhs
}

@_disfavoredOverload
@inline(__always)
func + (lhs: Float, rhs: CGFloat) -> CGFloat {
    CGFloat(lhs) + rhs
}

@_disfavoredOverload
@inline(__always)
func - (lhs: Float, rhs: CGFloat) -> CGFloat {
    CGFloat(lhs) - rhs
}
