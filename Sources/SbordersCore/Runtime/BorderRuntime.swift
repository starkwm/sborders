import AppKit
import OSLog
import StarkConfiguration
import StarkIPC

@MainActor
public final class BorderRuntime {
  private let store: ConfigurationStore
  private let server: WindowServerClient
  private let events: WindowEventSource
  private let missionControl: MissionControlObserver
  private let logger = Logger(subsystem: "com.starkwm.sborders", category: "runtime")
  private var coordinator = BorderCoordinator()
  private var borders: [UInt32: BorderWindow] = [:]
  private var ownedIDs = Set<UInt32>()
  private var observedIDs = Set<UInt32>()
  private var pending = PendingUpdates()
  private let transfers = WindowTransfers()
  private var resizeChecks: [UInt32: Task<Void, Never>] = [:]
  private var scheduled = false
  private var running = false
  private var retry: Task<Void, Never>?
  private var control: ControlServer?
  private var watcher: ConfigurationWatcher?
  private var accessibility: AccessibilityFocus?
  private var observers: [NSObjectProtocol] = []
  private var signals: [any DispatchSourceSignal] = []
  private var lastBackendError: String?
  private var eventCount = 0
  private var reconcileCount = 0
  private var focusQueryCount = 0
  private var suspended = false

  public init(configurationURL: URL, allowMissingConfiguration: Bool) throws {
    store = try ConfigurationStore(url: configurationURL, allowMissing: allowMissingConfiguration)
    server = try WindowServerClient()
    events = WindowEventSource(api: server.api)
    missionControl = MissionControlObserver(api: server.api)
  }

  public func run() throws {
    NSApplication.shared.setActivationPolicy(.prohibited)
    try checkFocusMode(store.configuration, prompt: true)

    let control = ControlServer(
      path: store.url.deletingLastPathComponent().appending(path: "control.sock").path,
      onStop: { [weak self] in
        DispatchQueue.main.async { self?.stop() }
      },
      handler: { [weak self] request in
        guard let self else { return ControlResponse(ok: false, error: "Daemon is stopping.") }

        return await self.handle(request)
      }
    )

    self.control = control
    try control.start()
    running = true

    do {
      try events.start { [weak self] event in DispatchQueue.main.async { self?.receive(event) } }
      missionControl.start { [weak self] in
        guard let self, self.running else { return }

        if self.missionControl.isActive {
          do { try self.render() } catch { self.report(error) }
        } else {
          self.pending.refresh()
          self.schedule()
          self.scheduleRetry()
        }
      }

      try reconcile()
    } catch {
      stop()
      throw error
    }

    watcher = ConfigurationWatcher(url: store.url) { [weak self] in self?.configurationChanged() }
    watcher?.start()
    observeWorkspace()

    for number in [SIGINT, SIGTERM] {
      signal(number, SIG_IGN)
      let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
      source.setEventHandler { [weak self] in self?.stop() }
      source.resume()
      signals.append(source)
    }

    logger.info("Started with \(self.coordinator.windows.count) windows")
    NSApplication.shared.run()
    stop()
  }

  public func stop() {
    guard running else {
      control?.stop()
      return
    }

    running = false
    retry?.cancel()
    retry = nil
    transfers.removeAll()

    for check in resizeChecks.values { check.cancel() }

    resizeChecks = [:]
    events.stop()
    missionControl.stop()
    try? server.subscribe(ids: [])
    watcher?.stop()
    watcher = nil

    for observer in observers {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
      NotificationCenter.default.removeObserver(observer)
    }

    observers = []

    for source in signals { source.cancel() }

    signals = []

    for border in borders.values { border.close() }

    borders = [:]
    ownedIDs = []
    control?.stop()
    control = nil
    NSApplication.shared.stop(nil)

    if let event = NSEvent.otherEvent(
      with: .applicationDefined,
      location: .zero,
      modifierFlags: [],
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      subtype: 0,
      data1: 0,
      data2: 0
    ) {
      NSApplication.shared.postEvent(event, atStart: true)
    }
  }

  private func receive(_ event: WindowEvent) {
    guard running else { return }

    if let id = event.windowID, ownedIDs.contains(id) { return }

    eventCount += 1

    if event.kind == .missionControl {
      missionControl.entered()
      return
    }

    if event.kind == .created, let id = event.windowID { missionControl.windowCreated(id: id) }

    if (event.kind == .focus && event.windowID == nil) || event.kind == .spaces
      || event.kind == .refresh
    {
      missionControl.checkForEntry()
    }

    if event.kind == .hidden, let id = event.windowID {
      resizeChecks.removeValue(forKey: id)?.cancel()
      borders[id]?.hide(target: id)
    }

    if event.kind == .closed, let id = event.windowID {
      transfers.remove(id)
      coordinator.remove(id)
      borders.removeValue(forKey: id)?.close()
      resizeChecks.removeValue(forKey: id)?.cancel()

      do { try updateSubscriptions() } catch { report(error) }
      updateOwnedIDs()
    } else if event.kind == .removedFromSpace, let id = event.windowID {
      transfers.insert(id) { [weak self] in
        guard let self, self.running else { return }

        self.pending.refresh()
        self.schedule()
      }

      resizeChecks.removeValue(forKey: id)?.cancel()

      if var window = coordinator.windows[id] {
        window.visible = false
        coordinator.update(window)
      }

      borders[id]?.hide(target: id)
    } else if event.kind == .resized, let id = event.windowID {
      scheduleResizeCheck(id: id)
    }

    pending.receive(event)

    schedule()

    if event.kind == .spaces || (event.kind == .focus && event.windowID == nil)
      || event.kind == .closed
      || event.kind == .removedFromSpace
    {
      scheduleRetry()
    }
  }

  private func schedule() {
    guard !scheduled else { return }

    scheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      self.scheduled = false

      guard self.running else { return }

      do { try self.flush() } catch { self.report(error) }
    }
  }

  private func flush() throws {
    let updates = pending.take()

    if updates.refreshAll {
      try reconcile()
      return
    }

    let ids = updates.metadataIDs
    let geometryIDs = updates.geometryIDs
    let needsFocus = updates.focus

    for id in geometryIDs {
      guard let previous = coordinator.windows[id] else { continue }

      if let snapshot = server.geometry(of: previous) {
        coordinator.update(snapshot)
      } else {
        var hidden = previous
        hidden.visible = false
        coordinator.update(hidden)
      }
    }

    let previous = Set(coordinator.windows.keys)

    for id in ids {
      if let snapshot = server.snapshot(id: id) {
        coordinator.update(snapshot)
      } else if transfers.ids.contains(id),
        var hidden = coordinator.windows[id]
      {
        hidden.visible = false
        coordinator.update(hidden)
      } else {
        coordinator.remove(id)
      }
    }

    if previous != Set(coordinator.windows.keys) {
      try updateSubscriptions()
    }

    if needsFocus { resolveFocus() }

    try render(only: needsFocus ? nil : ids.union(geometryIDs))
  }

  private func reconcile() throws {
    let snapshots = try server.windows()
    let transferIDs = transfers.ids

    coordinator.reconcile(
      snapshots,
      liveIDs: transferIDs.isEmpty ? nil : server.liveWindowIDs(),
      preservingIDs: transferIDs
    )

    for id in transferIDs
    where coordinator.windows[id] == nil || coordinator.windows[id]?.visible == true {
      transfers.remove(id)
    }

    for id in Array(resizeChecks.keys) where coordinator.windows[id] == nil {
      resizeChecks.removeValue(forKey: id)?.cancel()
    }

    try updateSubscriptions()
    resolveFocus()
    try render()
    reconcileCount += 1
    lastBackendError = nil
  }

  private func updateSubscriptions() throws {
    // Ordering a window out can make it temporarily disappear from queries.
    // Keep watching it until WindowServer confirms that the ID no longer exists.
    observedIDs = Set(observedIDs.filter { server.exists(id: $0) })
    observedIDs.formUnion(coordinator.windows.keys)
    try server.subscribe(ids: Array(observedIDs))
  }

  private func resolveFocus() {
    focusQueryCount += 1

    let id =
      store.configuration.focusMode == .accessibility
      ? accessibility?.focusedWindow() : server.frontWindow(in: Array(coordinator.windows.values))
    coordinator.focus(id)
  }

  private func render(only ids: Set<UInt32>? = nil) throws {
    let targets =
      suspended || missionControl.isActive
      ? [] : coordinator.visibleWindows(configuration: store.configuration)
    let visible = Set(targets.map(\.id))

    for id in Array(borders.keys) {
      if let window = coordinator.windows[id], store.configuration.enabled,
        store.configuration.allows(window)
      {
        continue
      }

      borders.removeValue(forKey: id)?.close()
    }

    for (id, border) in borders where !visible.contains(id) && (ids?.contains(id) ?? true) {
      border.hide(target: id)
    }

    defer { updateOwnedIDs() }

    for target in targets where ids?.contains(target.id) ?? true {
      let border = borders[target.id] ?? BorderWindow(api: server.api)
      borders[target.id] = border
      try border.update(
        target: target,
        configuration: store.configuration,
        focused: coordinator.focusedID == target.id,
        forceOrder: ids == nil
      )
    }
  }

  private func updateOwnedIDs() { ownedIDs = Set(borders.values.flatMap(\.ids).filter { $0 != 0 }) }

  private func scheduleResizeCheck(id: UInt32) {
    resizeChecks[id]?.cancel()
    resizeChecks[id] = Task { [weak self] in
      do { try await Task.sleep(for: .milliseconds(32)) } catch { return }

      guard let self, self.running else { return }

      self.resizeChecks.removeValue(forKey: id)
      self.pending.receive(WindowEvent(kind: .moved, windowID: id))
      self.schedule()
    }
  }

  private func scheduleRetry() {
    retry?.cancel()
    retry = Task { [weak self] in
      for delay in [30, 100, 250] {
        do { try await Task.sleep(for: .milliseconds(delay)) } catch { return }

        guard let self, self.running else { return }

        do { try self.reconcile() } catch { self.report(error) }
      }
    }
  }

  private func observeWorkspace() {
    let center = NSWorkspace.shared.notificationCenter

    for name in [
      NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification,
      NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didHideApplicationNotification,
      NSWorkspace.didUnhideApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification,
      NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification,
    ] {
      observers.append(
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
          MainActor.assumeIsolated {
            guard let self else { return }

            if name == NSWorkspace.didWakeNotification
              || name == NSWorkspace.sessionDidBecomeActiveNotification
            {
              self.suspended = false
            }

            self.pending.refresh()
            self.schedule()
            self.scheduleRetry()
          }
        }
      )
    }

    for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification]
    {
      observers.append(
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
          MainActor.assumeIsolated {
            guard let self else { return }

            self.suspended = true
            try? self.render()
          }
        }
      )
    }

    observers.append(
      NotificationCenter.default.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.receive(WindowEvent(kind: .refresh, windowID: nil)) }
      }
    )
  }

  private func checkFocusMode(_ configuration: Configuration, prompt: Bool) throws {
    guard configuration.focusMode == .accessibility else { return }

    if accessibility == nil { accessibility = try AccessibilityFocus() }

    try accessibility?.checkPermission(prompt: prompt)
  }

  private func configurationChanged() {
    do { try reload(ifChanged: true) } catch {
      logger.error("Configuration reload failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func reload(ifChanged: Bool = false) throws {
    let reloaded = try store.reload(ifChanged: ifChanged) { candidate in
      try self.checkFocusMode(candidate, prompt: false)
    }

    guard reloaded else { return }

    resolveFocus()

    do { try render() } catch {
      report(error)
      throw error
    }
  }

  private func handle(_ request: ControlRequest) -> ControlResponse {
    do {
      guard running else { throw MessageError.message("Daemon is stopping.") }

      switch try RuntimeCommand(request) {
      case .query(let subject):
        switch subject {
        case .config: return try response(store.configuration)
        case .windows:
          return try response(
            coordinator.windows.values.sorted { $0.id < $1.id }.map { window in
              WindowStatus(
                window: window,
                focused: coordinator.focusedID == window.id,
                borderID: borders[window.id]?.ids.first,
                borderIDs: borders[window.id]?.ids ?? [],
                borderFrame: borders[window.id]?.frame,
                borderVisible: borders[window.id]?.isVisible ?? false,
                borderSublevel: borders[window.id]?.sublevel,
                redrawCount: borders[window.id]?.redrawCount ?? 0,
                transactionCount: borders[window.id]?.transactionCount ?? 0,
                contextCreationCount: borders[window.id]?.contextCreationCount ?? 0
              )
            }
          )
        case .diagnostics:
          return try response(
            Diagnostics(
              pid: getpid(),
              windowCount: coordinator.windows.count,
              borderCount: borders.values.filter { !$0.ids.isEmpty }.count,
              eventCount: eventCount,
              reconcileCount: reconcileCount,
              geometryQueryCount: server.geometryQueryCount,
              metadataQueryCount: server.metadataQueryCount,
              focusQueryCount: focusQueryCount,
              configurationPath: store.url.path,
              hasOverrides: store.hasOverrides,
              configurationError: store.lastError,
              backendError: lastBackendError,
              focusMode: store.configuration.focusMode.rawValue,
              focusedWindowID: coordinator.focusedID,
              osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
              missionControlActive: missionControl.isActive
            )
          )
        }

      case .reload: try reload()
      case .set(let property, let value):
        try store.set(property, value: value) { candidate in
          try self.checkFocusMode(candidate, prompt: true)
        }

        resolveFocus()
        try render()
      case .stop: break
      }

      return ControlResponse()
    } catch {
      return ControlResponse(ok: false, error: error.localizedDescription)
    }
  }

  private func response(_ value: some Encodable) throws -> ControlResponse {
    ControlResponse(
      value: try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    )
  }

  private func report(_ error: any Error) {
    lastBackendError = error.localizedDescription
    logger.error("\(error.localizedDescription, privacy: .public)")
  }
}

private struct WindowStatus: Encodable {
  let window: WindowSnapshot
  let focused: Bool
  let borderID: UInt32?
  let borderIDs: [UInt32]
  let borderFrame: CGRect?
  let borderVisible: Bool
  let borderSublevel: Int32?
  let redrawCount: Int
  let transactionCount: Int
  let contextCreationCount: Int
}

private struct Diagnostics: Encodable {
  let pid: Int32
  let windowCount: Int
  let borderCount: Int
  let eventCount: Int
  let reconcileCount: Int
  let geometryQueryCount: Int
  let metadataQueryCount: Int
  let focusQueryCount: Int
  let configurationPath: String
  let hasOverrides: Bool
  let configurationError: String?
  let backendError: String?
  let focusMode: String
  let focusedWindowID: UInt32?
  let osVersion: String
  let missionControlActive: Bool
}
