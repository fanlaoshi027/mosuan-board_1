import AppKit

/// Describes how a new selection result should be combined with the current selection.
/// The renderer owns the selection storage; this type centralizes modifier-key semantics.
enum SelectionOperation: Equatable {
    case replace
    case add
    case subtract

    /// Shift adds to the current selection; Option subtracts from it.
    /// Option takes precedence when both modifiers are held.
    static func fromModifiers(_ flags: NSEvent.ModifierFlags) -> SelectionOperation {
        if flags.contains(.option) { return .subtract }
        if flags.contains(.shift) { return .add }
        return .replace
    }
}
