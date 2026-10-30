import Testing

@testable import SbordersCore

@Suite("PendingUpdates")
struct PendingUpdatesTests {
  @Test("receive(_:): metadata supersedes geometry in either order", arguments: [true, false])
  func metadataSupersedesGeometry(metadataFirst: Bool) {
    var pending = PendingUpdates()
    let kinds: [WindowEvent.Kind] = metadataFirst ? [.changed, .moved] : [.resized, .changed]
    for kind in kinds { pending.receive(WindowEvent(kind: kind, windowID: 1)) }
    pending.receive(WindowEvent(kind: .moved, windowID: 2))

    #expect(pending.metadataIDs == [1])
    #expect(pending.geometryIDs == [2])
    #expect(pending.focus)
  }

  @Test("receive(_:): full refresh supersedes queued and subsequent window updates")
  func fullRefreshSupersedesUpdates() {
    var pending = PendingUpdates()
    pending.receive(WindowEvent(kind: .changed, windowID: 1))
    pending.receive(WindowEvent(kind: .moved, windowID: 2))
    pending.receive(WindowEvent(kind: .removedFromSpace, windowID: 1))
    pending.receive(WindowEvent(kind: .resized, windowID: 3))
    pending.receive(WindowEvent(kind: .created, windowID: 4))

    #expect(pending.refreshAll)
    #expect(pending.metadataIDs.isEmpty)
    #expect(pending.geometryIDs.isEmpty)
    #expect(pending.focus)
  }

  @Test("receive(_:): closure removes queued work without losing other windows")
  func closesQueuedWindow() {
    var pending = PendingUpdates()
    pending.receive(WindowEvent(kind: .changed, windowID: 1))
    pending.receive(WindowEvent(kind: .resized, windowID: 2))
    pending.receive(WindowEvent(kind: .moved, windowID: 3))
    pending.receive(WindowEvent(kind: .closed, windowID: 1))
    pending.receive(WindowEvent(kind: .closed, windowID: 2))

    #expect(pending.metadataIDs.isEmpty)
    #expect(pending.geometryIDs == [3])
    #expect(pending.focus)

    pending.receive(WindowEvent(kind: .created, windowID: 1))
    #expect(pending.metadataIDs == [1])
  }

  @Test("take(): isolates successive batches and preserves focus-only updates")
  func drainsUpdates() {
    var pending = PendingUpdates()
    pending.refresh()
    let first = pending.take()
    pending.receive(WindowEvent(kind: .moved, windowID: 1))
    let second = pending.take()
    pending.receive(WindowEvent(kind: .focus, windowID: nil))
    let third = pending.take()

    #expect(first.refreshAll)
    #expect(!second.refreshAll)
    #expect(second.geometryIDs == [1])
    #expect(!second.focus)
    #expect(third.geometryIDs.isEmpty)
    #expect(third.metadataIDs.isEmpty)
    #expect(third.focus)
    #expect(!pending.focus)
  }
}
