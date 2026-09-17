import AppKit

/// One logical border, backed by small windows around the target's perimeter.
@MainActor
final class BorderWindow {
  private(set) var redrawCount = 0
  private(set) var transactionCount = 0
  private(set) var contextCreationCount = 0

  var ids: [UInt32] { surfaces.map(\.id) }

  var currentFrame: CGRect? {
    guard !surfaces.isEmpty else { return nil }
    var result = CGRect.null

    for surface in surfaces {
      var rect = CGRect.zero
      guard api.getBounds(api.connection, surface.id, &rect) == 0 else { return nil }
      result = result.union(rect)
    }

    return result
  }

  var isVisible: Bool {
    !surfaces.isEmpty
      && surfaces.allSatisfy { surface in
        var visible = false
        return api.isOrdered(api.connection, surface.id, &visible) == 0 && visible
      }
  }

  var sublevel: Int32? {
    surfaces.first.map { api.getSublevel(api.connection, $0.id) }
  }

  private let api: SkyLight
  private var surfaces: [BorderSurface] = []
  private var drawing: Drawing?
  private var appliedTarget: WindowSnapshot?
  private var orderedIn = false

  init(api: SkyLight) { self.api = api }

  func update(
    target: WindowSnapshot,
    configuration: Configuration,
    focused: Bool,
    forceOrder: Bool = false
  ) throws {
    let hex = focused ? configuration.activeColor : configuration.inactiveColor
    guard let color = BorderColor(hex: hex), color.alpha > 0 else {
      close()
      return
    }

    guard
      let geometry = BorderGeometry(
        target: target.frame,
        width: configuration.width,
        radius: target.cornerRadius
      )
    else {
      hide(target: target.id)
      return
    }

    let next = Drawing(
      size: geometry.frame.size,
      width: configuration.width,
      radius: geometry.radius,
      scale: target.scale,
      style: configuration.style,
      color: hex
    )

    if orderedIn && drawing == next && !forceOrder, var previous = appliedTarget {
      if previous == target { return }
      previous.frame = target.frame

      if previous == target {
        try position(target: target, geometry: geometry)
        return
      }
    }

    let tiles = geometry.tiles(scale: target.scale, style: configuration.style)

    // Very small windows can have no straight side sections.
    if surfaces.count != tiles.count {
      close()
      surfaces = tiles.map { _ in BorderSurface(api: api) }
    }

    do {
      for (surface, tile) in zip(surfaces, tiles) {
        let recreated = try surface.prepare(
          target: target,
          tile: tile,
          frame: geometry.screenFrame(for: tile)
        )
        if recreated { contextCreationCount += 1 }

        if recreated || drawing != next {
          surface.draw(geometry: geometry, tile: tile, color: color, style: configuration.style)
        }
      }

      if drawing != next { redrawCount += 1 }
      drawing = next
      try position(target: target, geometry: geometry)
    } catch {
      // Do not leave a partially updated border on screen after allocation failure.
      close()
      throw error
    }
  }

  func hide(target: UInt32) {
    guard orderedIn, let transaction = api.transaction(api.connection)?.takeRetainedValue() else {
      return
    }

    for surface in surfaces { api.order(transaction, surface.id, 0, target) }
    api.commit(transaction, 0)
    orderedIn = false
    transactionCount += 1
  }

  func close() {
    for surface in surfaces { surface.close() }
    surfaces = []
    drawing = nil
    appliedTarget = nil
    orderedIn = false
  }

  private func position(target: WindowSnapshot, geometry: BorderGeometry) throws {
    guard let transaction = api.transaction(api.connection)?.takeRetainedValue() else {
      throw MessageError.message("Cannot begin border transaction.")
    }

    for surface in surfaces {
      api.move(transaction, surface.id, geometry.screenFrame(for: surface.tile).origin)

      if appliedTarget?.level != target.level {
        api.setLevel(transaction, surface.id, target.level)
      }

      if appliedTarget?.sublevel != target.sublevel {
        api.setSublevel(transaction, surface.id, target.sublevel)
      }

      api.order(transaction, surface.id, -1, target.id)
    }

    api.commit(transaction, 0)
    transactionCount += 1
    appliedTarget = target
    orderedIn = true
  }
}

@MainActor
private final class BorderSurface {
  private(set) var id: UInt32 = 0
  private(set) var tile = CGRect.zero

  private let api: SkyLight
  private var context: CGContext?
  private var spaces: [UInt64] = []
  private var scale: Double?

  init(api: SkyLight) { self.api = api }

  func prepare(target: WindowSnapshot, tile: CGRect, frame: CGRect) throws -> Bool {
    if id == 0 {
      guard
        api.newWindow(api.connection, 2, -10000, -10000, try region(size: tile.size), &id) == 0,
        id != 0
      else {
        throw MessageError.message("Cannot create a border window.")
      }

      spaces =
        (api.copySpaces(api.connection, 7, [id] as CFArray)?.takeRetainedValue() as? [NSNumber]
        ?? []).map(\.uint64Value)
      api.setOpacity(api.connection, id, false)
      api.shadow(id, ["com.apple.WindowShadowDensity": 0] as CFDictionary)
    }

    var tags: UInt64 = (1 << 1) | (1 << 9) | (1 << 18)
    if target.sticky { tags |= 1 << 11 }
    api.setTags(api.connection, id, &tags, 64)

    if !target.sticky {
      var sticky: UInt64 = 1 << 11
      api.clearTags(api.connection, id, &sticky, 64)
    }

    if spaces != target.spaces {
      let previous = Set(spaces)
      let next = Set(target.spaces)
      let added = Array(next.subtracting(previous))
      let removed = Array(previous.subtracting(next))

      if !added.isEmpty { api.addToSpaces(api.connection, [id] as CFArray, added as CFArray) }
      if !removed.isEmpty {
        api.removeFromSpaces(api.connection, [id] as CFArray, removed as CFArray)
      }
      spaces = target.spaces
    }

    let recreate = context == nil || self.tile.size != tile.size || scale != target.scale
    if recreate { context = nil }
    if scale != target.scale { api.setResolution(api.connection, id, target.scale) }

    if self.tile.size != tile.size {
      api.setShape(
        api.connection,
        id,
        Float(frame.minX),
        Float(frame.minY),
        try region(size: tile.size)
      )
    }

    if recreate {
      guard let context = api.createContext(api.connection, id, nil)?.takeRetainedValue() else {
        throw MessageError.message("Cannot create a border drawing context.")
      }
      self.context = context
    }

    self.tile = tile
    scale = target.scale
    return recreate
  }

  func draw(geometry: BorderGeometry, tile: CGRect, color: BorderColor, style: Configuration.Style)
  {
    guard let context else { return }
    BorderRenderer.draw(in: context, geometry: geometry, color: color, style: style, tile: tile)
    context.flush()
    api.flush(api.connection, id, nil)
  }

  func close() {
    context = nil
    if id != 0 { api.releaseWindow(api.connection, id) }
    id = 0
    tile = .zero
    spaces = []
    scale = nil
  }

  private func region(size: CGSize) throws -> CFTypeRef {
    var rect = CGRect(origin: .zero, size: size)
    var raw: Unmanaged<CFTypeRef>?
    guard api.newRegion(&rect, &raw) == 0, let raw else {
      throw MessageError.message("Cannot create border region.")
    }
    return raw.takeRetainedValue()
  }
}

private struct Drawing: Equatable {
  let size: CGSize
  let width: Double
  let radius: Double
  let scale: Double
  let style: Configuration.Style
  let color: String
}
