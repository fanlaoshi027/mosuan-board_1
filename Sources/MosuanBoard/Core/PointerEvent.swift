import Foundation
import simd

/// Platform-independent pointer/pen input used by the Mosuan editing core.
/// Platform adapters (AppKit, UIKit/PencilKit, Windows Pointer API) convert their
/// native events into this value before they reach editing logic.
struct MosuanPointerEvent: Equatable {
    enum Phase: String, Codable {
        case began
        case changed
        case ended
        case cancelled
    }

    enum DeviceType: String, Codable {
        case mouse
        case pen
        case touch
        case unknown
    }

    var position: SIMD2<Float>
    var pressure: Float
    var tilt: SIMD2<Float>
    var azimuth: Float
    var phase: Phase
    var deviceType: DeviceType
    var buttons: UInt32
    var modifiers: UInt32
    /// Monotonic input timestamp when the platform exposes one.
    /// Used for pressure-free speed-based nib dynamics.
    var timestamp: TimeInterval

    init(
        position: SIMD2<Float>,
        pressure: Float = 1,
        tilt: SIMD2<Float> = .zero,
        azimuth: Float = 0,
        phase: Phase,
        deviceType: DeviceType,
        buttons: UInt32 = 0,
        modifiers: UInt32 = 0,
        timestamp: TimeInterval = 0
    ) {
        self.position = position
        self.pressure = pressure
        self.tilt = tilt
        self.azimuth = azimuth
        self.phase = phase
        self.deviceType = deviceType
        self.buttons = buttons
        self.modifiers = modifiers
        self.timestamp = timestamp
    }
}
