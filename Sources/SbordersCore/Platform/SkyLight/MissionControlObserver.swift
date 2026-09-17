import AppKit

/// Tracks overview windows without Accessibility or Screen Recording permission.
@MainActor
final class MissionControlObserver {
  nonisolated static func isOverview(owner: String?, layer: Int) -> Bool {
    (owner == "com.apple.dock" && layer == 18)
      || (owner == "com.apple.WindowManager" && layer == 19)
  }

  var isActive: Bool { state.isActive }

  private let api: SkyLight
  private var checkUntil: TimeInterval = 0
  private var state = MissionControlState()
  private var poll: Task<Void, Never>?
  private var onChange: (@MainActor () -> Void)?

  init(api: SkyLight) { self.api = api }

  func start(onChange: @escaping @MainActor () -> Void) {
    self.onChange = onChange
    checkForEntry()
  }

  func entered() {
    let wasActive = isActive
    state.entered(at: ProcessInfo.processInfo.systemUptime)

    if !wasActive { onChange?() }
    watchForExit()
  }

  func windowCreated(id: UInt32) {
    var connection: Int32 = 0
    var pid: Int32 = 0

    guard api.getOwner(api.connection, id, &connection) == 0,
      api.getPID(connection, &pid) == 0,
      let owner = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
      owner == "com.apple.dock" || owner == "com.apple.WindowManager"
    else { return }

    checkForEntry()
  }

  func checkForEntry() {
    // Creation and focus events can arrive before the overview is ordered in.
    checkUntil = ProcessInfo.processInfo.systemUptime + 0.5
    sample()
    watchForExit()
  }

  func stop() {
    poll?.cancel()
    poll = nil
    onChange = nil
    state = MissionControlState()
  }

  private func sample() {
    let wasActive = isActive
    state.update(overviewVisible: overviewVisible(), at: ProcessInfo.processInfo.systemUptime)

    if wasActive != isActive { onChange?() }
  }

  private func watchForExit() {
    guard poll == nil else { return }

    poll = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .milliseconds(100)) } catch { return }

        guard let self else { return }

        self.sample()

        if !self.isActive && ProcessInfo.processInfo.systemUptime >= self.checkUntil {
          self.poll = nil
          return
        }
      }
    }
  }

  private func overviewVisible() -> Bool? {
    guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, 0) as? [[String: Any]]
    else { return nil }

    // Dock owns the overview on macOS 26. WindowManager owns its shield on
    // macOS 27. Titles are redacted without Screen Recording permission.
    return windows.contains { window in
      guard let layer = window[kCGWindowLayer as String] as? Int,
        layer == 18 || layer == 19,
        let pid = window[kCGWindowOwnerPID as String] as? Int32
      else { return false }

      return Self.isOverview(
        owner: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
        layer: layer
      )
    }
  }
}

struct MissionControlState {
  private(set) var isActive = false

  private var earliestExit: TimeInterval = 0
  private var missingSamples = 0

  mutating func entered(at time: TimeInterval) {
    isActive = true
    // The notification can precede creation of the overview window.
    earliestExit = time + 0.5
    missingSamples = 0
  }

  mutating func update(overviewVisible: Bool?, at time: TimeInterval) {
    guard let overviewVisible else {
      missingSamples = 0
      return
    }

    if overviewVisible {
      isActive = true
      missingSamples = 0
    } else if isActive && time >= earliestExit {
      missingSamples += 1
      // Avoid restoring borders during a transient gap between Dock windows.
      if missingSamples >= 2 { isActive = false }
    }
  }
}
