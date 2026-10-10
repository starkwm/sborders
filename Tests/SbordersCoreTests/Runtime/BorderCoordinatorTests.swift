import Foundation
import Testing

@testable import SbordersCore

@Suite("BorderCoordinator")
struct BorderCoordinatorTests {
  @Test("replace(_:): removes duplicate windows and clears missing focus") func replacesWindows() {
    var state = BorderCoordinator()
    state.replace([window(), window(id: 2)])
    state.focus(2)
    state.replace([window(), window()])

    #expect(state.windows.count == 1)
    #expect(state.focusedID == nil)
  }

  @Test("reconcile(_:liveIDs:preservingIDs:): retains windows during transfer")
  func retainsWindowsDuringTransfer() {
    var state = BorderCoordinator()
    state.update(window())
    state.reconcile([], liveIDs: [1], preservingIDs: [1])

    #expect(state.windows[1]?.visible == false)
    #expect(state.visibleWindows(configuration: Configuration()).isEmpty)

    state.reconcile([window()], liveIDs: [1])

    #expect(state.windows[1]?.visible == true)

    state.reconcile([], liveIDs: [], preservingIDs: [1])

    #expect(state.windows.isEmpty)
  }

  @Test("reconcile(_:liveIDs:preservingIDs:): retains windows after a failed query")
  func retainsWindowsAfterFailedQuery() {
    var state = BorderCoordinator()
    state.update(window())
    state.reconcile([], liveIDs: nil, preservingIDs: [1])

    #expect(state.windows[1]?.visible == false)
  }

  @Test("remove(_:): clears focus before a window ID is reused") func reusedIDClearsFocus() {
    var state = BorderCoordinator()
    state.update(window())
    state.focus(1)
    state.remove(1)
    state.update(window(pid: 20))

    #expect(state.focusedID == nil)
    #expect(state.windows[1]?.pid == 20)
  }

  @Test("focus(_:): skips hidden and fullscreen windows") func skipsHiddenAndFullscreenWindows() {
    var state = BorderCoordinator()
    state.replace([window(visible: false), window(id: 2, fullscreen: true)])
    state.focus(1)

    #expect(state.focusedID == nil)

    state.focus(2)

    #expect(state.focusedID == nil)
    #expect(state.visibleWindows(configuration: Configuration()).isEmpty)
  }

  @Test("visibleWindows(configuration:): filters windows by configuration")
  func filtersVisibleWindows() {
    var state = BorderCoordinator()
    state.replace([window()])

    var config = Configuration()
    config.includeApps = [AppMatcher(bundleID: "test.app")]

    #expect(state.visibleWindows(configuration: config).count == 1)

    config.excludeApps = [AppMatcher(processName: "Test")]

    #expect(state.visibleWindows(configuration: config).isEmpty)

    config.excludeApps = []
    config.enabled = false

    #expect(state.visibleWindows(configuration: config).isEmpty)
  }
}

func window(id: UInt32 = 1, pid: Int32 = 10, visible: Bool = true, fullscreen: Bool = false)
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
