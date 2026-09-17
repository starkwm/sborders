import AppKit

@MainActor
final class WindowServerClient {
  let api: SkyLight
  private(set) var geometryQueryCount = 0
  private(set) var metadataQueryCount = 0

  private var visibleSpaces = Set<UInt64>()
  private var allSpaces: [UInt64] = []

  init() throws { api = try SkyLight() }

  func windows() throws -> [WindowSnapshot] {
    try refreshSpaces()

    var set: UInt64 = 0
    var clear: UInt64 = 0

    guard
      let ids = api.copyWindows(api.connection, 0, allSpaces as CFArray, 7, &set, &clear)?
        .takeRetainedValue()
    else {
      throw MessageError.message("Cannot enumerate windows.")
    }

    return snapshots(ids: ids)
  }

  func snapshot(id: UInt32) -> WindowSnapshot? { snapshots(ids: [id] as CFArray).first }

  /// Ordinary geometry notifications need only bounds. Refresh metadata when the
  /// window crosses displays, including displays with the same backing scale.
  func geometry(of previous: WindowSnapshot) -> WindowSnapshot? {
    if !previous.visible { return snapshot(id: previous.id) }

    geometryQueryCount += 1
    var frame = CGRect.zero

    guard api.getBounds(api.connection, previous.id, &frame) == 0,
      frame.width > 0, frame.height > 0,
      [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite)
    else { return nil }

    if displayIntersecting(frame) != displayIntersecting(previous.frame) {
      try? refreshSpaces()

      return snapshot(id: previous.id)
    }

    var result = previous
    result.frame = frame

    return result
  }

  /// Unlike owner queries, the complete list also establishes liveness after
  /// Space removal without mistaking an offscreen window for a closed one.
  func liveWindowIDs() -> Set<UInt32>? {
    guard
      let rows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], 0)
        as? [[String: Any]]
    else { return nil }

    return Set(rows.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value })
  }

  func exists(id: UInt32) -> Bool {
    var owner: Int32 = 0

    return api.getOwner(api.connection, id, &owner) == 0 && owner != 0
  }

  func subscribe(ids: [UInt32]) throws {
    let result = ids.withUnsafeBufferPointer {
      api.notifications(api.connection, $0.baseAddress, Int32($0.count))
    }

    guard result == 0 else {
      throw MessageError.message("Window notification subscription failed: \(result).")
    }
  }

  func frontWindow(in windows: [WindowSnapshot]) -> UInt32? {
    guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }

    let eligible = Set(windows.filter { $0.pid == pid && $0.visible && !$0.fullscreen }.map(\.id))

    // CGWindowList preserves front-to-back ordering, including multiple windows of one app.
    let ordered =
      CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0)
      as? [[String: Any]] ?? []

    return ordered.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }.first {
      eligible.contains($0)
    }
  }

  private func refreshSpaces() throws {
    guard let raw = api.copyDisplaySpaces(api.connection)?.takeRetainedValue() else {
      throw MessageError.message("Cannot read display Spaces.")
    }

    let displays = raw as? [[String: Any]] ?? []
    allSpaces = []
    visibleSpaces = []

    for display in displays {
      if let current = display["Current Space"] as? [String: Any],
        let id = current["id64"] as? UInt64
      {
        visibleSpaces.insert(id)
      }

      for space in display["Spaces"] as? [[String: Any]] ?? [] {
        if let id = space["id64"] as? UInt64 { allSpaces.append(id) }
      }
    }

    guard !allSpaces.isEmpty else { throw MessageError.message("No desktop Spaces are available.") }
  }

  private func snapshots(ids: CFArray) -> [WindowSnapshot] {
    metadataQueryCount += 1

    guard let query = api.query(api.connection, ids, 0)?.takeRetainedValue(),
      let iterator = api.iterator(query)?.takeRetainedValue()
    else { return [] }

    var result: [WindowSnapshot] = []

    while api.advance(iterator) {
      let id = api.windowID(iterator)
      let tags = api.tags(iterator)

      guard
        WindowEligibility.accepts(
          parent: api.parentID(iterator),
          attributes: api.attributes(iterator),
          tags: tags
        )
      else { continue }

      var owner: Int32 = 0
      var pid: pid_t = 0

      guard api.getOwner(api.connection, id, &owner) == 0, api.getPID(owner, &pid) == 0,
        pid != getpid()
      else { continue }

      var frame = CGRect.zero

      guard api.getBounds(api.connection, id, &frame) == 0, frame.width > 0, frame.height > 0,
        [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite)
      else { continue }

      let spaces =
        (api.copySpaces(api.connection, 7, [id] as CFArray)?.takeRetainedValue() as? [NSNumber]
        ?? []).map(\.uint64Value)
      var ordered = false

      guard api.isOrdered(api.connection, id, &ordered) == 0 else { continue }

      let sticky = tags & (1 << 11) != 0
      let app = NSRunningApplication(processIdentifier: pid)
      let radiusValues = api.radii?(iterator)?.takeRetainedValue() as? [NSNumber]
      let radius = radiusValues?.first?.doubleValue ?? 9
      let display = displayIntersecting(frame)
      let scale =
        NSScreen.screens.first {
          ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            == display
        }?.backingScaleFactor ?? 1

      result.append(
        WindowSnapshot(
          id: id,
          pid: pid,
          bundleID: app?.bundleIdentifier,
          processName: app?.localizedName ?? "\(pid)",
          frame: frame,
          level: api.level(iterator),
          sublevel: api.getSublevel(api.connection, id),
          spaces: spaces,
          sticky: sticky,
          visible: ordered && (sticky || !visibleSpaces.isDisjoint(with: spaces)),
          fullscreen: spaces.contains { api.spaceType(api.connection, $0) == 4 },
          cornerRadius: radius > 0 ? radius : 9,
          scale: scale
        )
      )
    }

    return result
  }

  private func displayIntersecting(_ rect: CGRect) -> CGDirectDisplayID {
    var display: CGDirectDisplayID = 0
    var count: UInt32 = 0
    CGGetDisplaysWithRect(rect, 1, &display, &count)

    return display
  }
}
