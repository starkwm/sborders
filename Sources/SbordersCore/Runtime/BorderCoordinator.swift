import Foundation

/// Pure state reconciliation. Platform windows are owned separately by BorderRuntime.
struct BorderCoordinator {
  private(set) var windows: [UInt32: WindowSnapshot] = [:]
  private(set) var focusedID: UInt32?

  mutating func replace(_ snapshots: [WindowSnapshot]) {
    windows = Dictionary(snapshots.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    if let focusedID, windows[focusedID] == nil { self.focusedID = nil }
  }

  /// A Space-scoped disappearance is not proof of closure. Keep a hidden
  /// snapshot while the complete server inventory still contains its ID.
  mutating func reconcile(
    _ snapshots: [WindowSnapshot],
    liveIDs: Set<UInt32>?,
    preservingIDs: Set<UInt32> = []
  ) {
    var combined = snapshots
    let found = Set(snapshots.map(\.id))
    for var previous in windows.values
    where preservingIDs.contains(previous.id) && !found.contains(previous.id)
      && (liveIDs?.contains(previous.id) ?? true)
    {
      previous.visible = false
      combined.append(previous)
    }
    replace(combined)
  }

  mutating func update(_ snapshot: WindowSnapshot) { windows[snapshot.id] = snapshot }

  mutating func remove(_ id: UInt32) {
    windows.removeValue(forKey: id)
    if focusedID == id { focusedID = nil }
  }

  mutating func focus(_ id: UInt32?) {
    focusedID = id.flatMap { id in
      guard let window = windows[id], window.visible, !window.fullscreen else { return nil }
      return id
    }
  }

  func visibleWindows(configuration: Configuration) -> [WindowSnapshot] {
    guard configuration.enabled else { return [] }
    return windows.values.filter { $0.visible && !$0.fullscreen && configuration.allows($0) }
  }
}
