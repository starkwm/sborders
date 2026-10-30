/// Coalesces notifications until the next run-loop turn.
struct PendingUpdates {
  private(set) var metadataIDs = Set<UInt32>()
  private(set) var geometryIDs = Set<UInt32>()
  private(set) var focus = false
  private(set) var refreshAll = false

  mutating func receive(_ event: WindowEvent) {
    switch event.kind {
    case .missionControl: return
    case .spaces, .refresh, .removedFromSpace:
      refresh()
    case .closed:
      if let id = event.windowID {
        metadataIDs.remove(id)
        geometryIDs.remove(id)
      }
      focus = true
    case .focus:
      focus = true
    case .moved, .resized:
      if !refreshAll, let id = event.windowID, !metadataIDs.contains(id) {
        geometryIDs.insert(id)
      }
    case .created, .changed, .hidden:
      if !refreshAll, let id = event.windowID {
        metadataIDs.insert(id)
        geometryIDs.remove(id)
      }
      focus = true
    }
  }

  mutating func refresh() {
    refreshAll = true
    metadataIDs = []
    geometryIDs = []
    focus = true
  }

  mutating func take() -> PendingUpdates {
    defer { self = PendingUpdates() }

    return self
  }
}
