import Foundation
import Testing

@testable import SbordersCore

func fixtureWindow(id: UInt32 = 1, pid: Int32 = 10, visible: Bool = true, fullscreen: Bool = false)
  -> WindowSnapshot
{
  WindowSnapshot(
    id: id,
    pid: pid,
    bundleID: "test.app",
    processName: "Test",
    frame: CGRect(x: 100, y: 100, width: 400, height: 300),
    level: 0,
    sublevel: 0,
    spaces: [1],
    sticky: false,
    visible: visible,
    fullscreen: fullscreen,
    cornerRadius: 16,
    scale: 2
  )
}

@Test func closingAndReusingAnIDDoesNotRetainFocus() {
  var state = BorderCoordinator()
  state.update(fixtureWindow())
  state.focus(1)
  state.remove(1)
  state.update(fixtureWindow(pid: 20))

  #expect(state.focusedID == nil)
  #expect(state.windows[1]?.pid == 20)
}

@Test func reconciliationRemovesAbsentWindowsAndToleratesDuplicates() {
  var state = BorderCoordinator()
  state.replace([fixtureWindow(), fixtureWindow(id: 2)])
  state.focus(2)
  state.replace([fixtureWindow(), fixtureWindow()])

  #expect(state.windows.count == 1)
  #expect(state.focusedID == nil)
}

@Test func hiddenAndFullscreenWindowsCannotBeFocusedOrRendered() {
  var state = BorderCoordinator()
  state.replace([fixtureWindow(visible: false), fixtureWindow(id: 2, fullscreen: true)])
  state.focus(1)

  #expect(state.focusedID == nil)

  state.focus(2)

  #expect(state.focusedID == nil)
  #expect(state.visibleWindows(configuration: Configuration()).isEmpty)
}

@Test func exclusionWinsAndDisabledClearsBorders() {
  var state = BorderCoordinator()
  state.replace([fixtureWindow()])
  var config = Configuration()
  config.includeApps = [AppMatcher(bundleID: "test.app")]

  #expect(state.visibleWindows(configuration: config).count == 1)

  config.excludeApps = [AppMatcher(processName: "Test")]

  #expect(state.visibleWindows(configuration: config).isEmpty)

  config.excludeApps = []
  config.enabled = false

  #expect(state.visibleWindows(configuration: config).isEmpty)
}

@Test func eligibilityExcludesAttachedAndCycleIgnoringWindows() {
  #expect(WindowEligibility.accepts(parent: 0, attributes: 2, tags: 1))
  #expect(!WindowEligibility.accepts(parent: 1, attributes: 2, tags: 1))
  #expect(!WindowEligibility.accepts(parent: 0, attributes: 2, tags: 1 | (1 << 7)))
  #expect(!WindowEligibility.accepts(parent: 0, attributes: 2, tags: 1 | (1 << 18)))
}

@Test func eventDecodingChecksLengthAndReadsUnalignedPayloads() {
  let bytes: [UInt8] = [255, 0, 0, 0, 0, 0, 0, 0, 0, 42, 0, 0, 0]
  bytes.withUnsafeBytes { raw in
    let pointer = raw.baseAddress!.advanced(by: 1)

    #expect(WindowEvent.decode(code: 1325, data: pointer, count: 11) == nil)
    #expect(WindowEvent.decode(code: 1325, data: pointer, count: 12)?.windowID == 42)
    #expect(WindowEvent.decode(code: 804, data: pointer, count: 0) == nil)
  }

  #expect(WindowEvent.decode(code: 1508, data: nil, count: 0)?.kind == .focus)
}

@Test func spaceRemovalPreservesLiveWindowsUntilTheyReturn() {
  var state = BorderCoordinator()
  state.update(fixtureWindow())
  state.reconcile([], liveIDs: [1], preservingIDs: [1])

  #expect(state.windows[1]?.visible == false)
  #expect(state.visibleWindows(configuration: Configuration()).isEmpty)

  state.reconcile([fixtureWindow()], liveIDs: [1])

  #expect(state.windows[1]?.visible == true)

  state.reconcile([], liveIDs: [], preservingIDs: [1])

  #expect(state.windows.isEmpty)
}

@Test func failedLivenessQueryDoesNotDestroyTrackedWindows() {
  var state = BorderCoordinator()
  state.update(fixtureWindow())
  state.reconcile([], liveIDs: nil, preservingIDs: [1])

  #expect(state.windows[1]?.visible == false)
}

@Test func geometryAndLifecycleNotificationsRemainDistinct() {
  let cases: [(UInt32, WindowEvent.Kind)] = [
    (804, .closed), (806, .moved), (807, .resized), (808, .changed),
    (811, .changed), (815, .changed), (816, .hidden), (1322, .focus),
    (723, .focus), (1325, .created), (1326, .removedFromSpace),
  ]
  for (code, kind) in cases {
    let words: [UInt32] = code == 1325 || code == 1326 ? [0, 0, 42] : [42]
    words.withUnsafeBytes { bytes in
      let event = WindowEvent.decode(code: code, data: bytes.baseAddress, count: bytes.count)

      #expect(event == WindowEvent(kind: kind, windowID: 42))
    }
  }
}

@Test func expiredTransferDoesNotRetainClosedButStillAllocatedWindows() {
  var state = BorderCoordinator()
  state.update(fixtureWindow())
  state.reconcile([], liveIDs: [1], preservingIDs: [1])

  #expect(state.windows[1] != nil)

  state.reconcile([], liveIDs: [1])

  #expect(state.windows.isEmpty)
}
