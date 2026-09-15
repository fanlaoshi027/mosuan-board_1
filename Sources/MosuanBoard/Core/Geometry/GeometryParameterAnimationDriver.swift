import CoreGraphics
import Foundation

/// Platform-neutral animation driver for dynamic geometry parameters.
///
/// The driver owns only runtime playback state. A platform display link/timer
/// supplies deltaTime, while the geometry core remains deterministic and testable.
struct GeometryParameterAnimationDriver: Equatable {
    private(set) var states: [UUID: GeometryParameterAnimationState] = [:]

    mutating func setPlaying(_ playing: Bool, parameterID: UUID) {
        var state = states[parameterID] ?? GeometryParameterAnimationState()
        state.isPlaying = playing
        states[parameterID] = state
    }

    mutating func toggle(parameterID: UUID) {
        var state = states[parameterID] ?? GeometryParameterAnimationState()
        state.toggle()
        states[parameterID] = state
    }

    mutating func stop(parameterID: UUID) {
        var state = states[parameterID] ?? GeometryParameterAnimationState()
        state.stop()
        states[parameterID] = state
    }

    mutating func stopAll() {
        for id in states.keys { states[id]?.stop() }
    }

    func isPlaying(parameterID: UUID) -> Bool {
        states[parameterID]?.isPlaying ?? false
    }

    var isPlayingAny: Bool {
        states.values.contains(where: { $0.isPlaying })
    }

    /// Advances every playing parameter, then resolves the complete geometry graph.
    /// This is the single update path that UI, recording and future Windows/iPad
    /// render loops can share.
    mutating func advance(model: inout GeometryModel, deltaTime: CGFloat) {
        guard deltaTime > 0 else { return }

        for index in model.parameters.indices {
            let id = model.parameters[index].id
            var state = states[id] ?? GeometryParameterAnimationState()
            state.advance(parameter: &model.parameters[index], deltaTime: deltaTime)
            states[id] = state
        }

        if isPlayingAny {
            GeometryConstraintSolver.apply(&model)
        }
    }
}
