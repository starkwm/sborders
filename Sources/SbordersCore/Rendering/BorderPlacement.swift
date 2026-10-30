import CoreGraphics

/// Only the target properties that affect border preparation and ordering.
struct BorderPlacement: Equatable {
  enum Update { case unchanged, position, prepare }

  let id: UInt32
  let frame: CGRect
  let level: Int32
  let sublevel: Int32
  let spaces: [UInt64]
  let sticky: Bool

  init(_ target: WindowSnapshot) {
    id = target.id
    frame = target.frame
    level = target.level
    sublevel = target.sublevel
    spaces = target.spaces
    sticky = target.sticky
  }

  func update(
    from previous: BorderPlacement?,
    drawingChanged: Bool,
    orderedIn: Bool,
    forceOrder: Bool
  ) -> Update {
    guard let previous, orderedIn, !forceOrder, !drawingChanged,
      previous.id == id, previous.spaces == spaces, previous.sticky == sticky
    else { return .prepare }

    return previous == self ? .unchanged : .position
  }
}
