import CoreGraphics
import Foundation

/// Owns runtime playback for one dynamic isosceles triangle.
///
/// SwiftUI only requests play/pause; timing and parameter advancement live here.
/// The geometry model remains the source of truth for range, step, speed and loop mode.
final class DynamicIsoscelesTrianglePlaybackController {
    private var triangle: DynamicIsoscelesTriangle?
    private var animationDriver = DynamicIsoscelesTriangleAnimationDriver()
    private var timer: Timer?
    private var setAngle: ((CGFloat) -> Void)?

    deinit {
        timer?.invalidate()
    }

    var isPlaying: Bool {
        guard let id = triangle?.id else { return false }
        return animationDriver.isPlaying(triangleID: id)
    }

    func start(currentAngle: CGFloat, setAngle: @escaping (CGFloat) -> Void) {
        stopTimerOnly()

        let model = DynamicIsoscelesTriangle(
            anchor: .zero,
            legLength: 150,
            apexAngleDegrees: currentAngle,
            minimum: 30,
            maximum: 150,
            step: 1,
            animationSpeed: 1,
            animationLoop: .pingPong
        )
        triangle = model
        self.setAngle = setAngle
        animationDriver.setPlaying(true, triangleID: model.id)
        startTimerIfNeeded()
    }

    func stop() {
        animationDriver.stopAll()
        stopTimerOnly()
        triangle = nil
        setAngle = nil
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.advance(deltaTime: 1.0 / 30.0)
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func advance(deltaTime: CGFloat) {
        guard var triangle, isPlaying else {
            stopTimerOnly()
            return
        }

        animationDriver.advance(triangle: &triangle, deltaTime: deltaTime)
        self.triangle = triangle
        setAngle?(triangle.apexAngleDegrees)
    }

    private func stopTimerOnly() {
        timer?.invalidate()
        timer = nil
    }
}
