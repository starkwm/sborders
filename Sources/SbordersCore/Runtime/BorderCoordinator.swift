import Foundation

/// Pure state reconciliation. Platform windows are owned separately by BorderRuntime.
struct BorderCoordinator {
  private(set) var windows: [UInt32: WindowSnapshot] = [:]
  private(set) var focusedID: UInt32?

  mutating func replace(_ snapshots: [WindowSnapshot]) {
    windows = Dictionary(snapshots.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    if let focusedID, windows[focusedID] == nil { self.focusedID = nil }
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
