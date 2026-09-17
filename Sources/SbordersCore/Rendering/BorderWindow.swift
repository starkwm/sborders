import AppKit

@MainActor
final class BorderWindow {
  private(set) var id: UInt32 = 0
  private(set) var redrawCount = 0
  private(set) var transactionCount = 0
  private(set) var contextCreationCount = 0
  private(set) var frame = CGRect.zero

  var currentFrame: CGRect? {
    var rect = CGRect.zero

    return id != 0 && api.getBounds(api.connection, id, &rect) == 0 ? rect : nil
  }

  var isVisible: Bool {
    var visible = false

    return id != 0 && api.isOrdered(api.connection, id, &visible) == 0 && visible
  }

  var sublevel: Int32 { api.getSublevel(api.connection, id) }

  private let api: SkyLight
  private var context: CGContext?
  private var spaces: [UInt64] = []
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
      color: focused ? configuration.activeColor : configuration.inactiveColor
    )

    if orderedIn && drawing == next && !forceOrder, var previous = appliedTarget {
      if previous == target { return }
      previous.frame = target.frame

      if previous == target {
        try position(target: target, frame: geometry.frame)
        return
      }
    }

    if id == 0 {
      var local = CGRect(origin: .zero, size: geometry.frame.size)
      let region = try region(&local)

      guard api.newWindow(api.connection, 2, -10000, -10000, region, &id) == 0, id != 0 else {
        close()
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

    if drawing?.scale != next.scale { api.setResolution(api.connection, id, next.scale) }

    if frame.size != geometry.frame.size {
      var local = CGRect(origin: .zero, size: geometry.frame.size)
      api.setShape(
        api.connection,
        id,
        Float(geometry.frame.minX),
        Float(geometry.frame.minY),
        try region(&local)
      )
    }

    // Rebind after shape or resolution changes so drawing covers the current
    // backing store, including newly exposed pixels when the window grows.
    if context == nil || drawing?.size != next.size || drawing?.scale != next.scale {
      guard let replacement = api.createContext(api.connection, id, nil)?.takeRetainedValue() else {
        hide(target: target.id)
        context = nil
        drawing = nil
        frame = .zero
        throw MessageError.message("Cannot create a border drawing context.")
      }

      context = replacement
      contextCreationCount += 1
    }

    if drawing != next {
      draw(geometry, drawing: next)
      drawing = next
      redrawCount += 1
    }

    try position(target: target, frame: geometry.frame)
  }

  func hide(target: UInt32) {
    guard orderedIn, id != 0, let transaction = api.transaction(api.connection)?.takeRetainedValue()
    else {
      return
    }

    orderedIn = false
    api.order(transaction, id, 0, target)
    api.commit(transaction, 0)
    transactionCount += 1
  }

  func close() {
    context = nil

    if id != 0 { api.releaseWindow(api.connection, id) }
    id = 0
    spaces = []
    drawing = nil
    appliedTarget = nil
    orderedIn = false
    frame = .zero
  }

  private func position(target: WindowSnapshot, frame: CGRect) throws {
    guard let transaction = api.transaction(api.connection)?.takeRetainedValue() else {
      throw MessageError.message("Cannot begin border transaction.")
    }

    api.move(transaction, id, frame.origin)

    if appliedTarget?.level != target.level { api.setLevel(transaction, id, target.level) }

    if appliedTarget?.sublevel != target.sublevel {
      api.setSublevel(transaction, id, target.sublevel)
    }

    api.order(transaction, id, -1, target.id)
    api.commit(transaction, 0)
    transactionCount += 1
    self.frame = frame
    appliedTarget = target
    orderedIn = true
  }

  private func region(_ rect: inout CGRect) throws -> CFTypeRef {
    var raw: Unmanaged<CFTypeRef>?

    guard api.newRegion(&rect, &raw) == 0, let raw else {
      throw MessageError.message("Cannot create border region.")
    }

    return raw.takeRetainedValue()
  }

  private func draw(_ geometry: BorderGeometry, drawing: Drawing) {
    guard let context, let color = BorderColor(hex: drawing.color) else { return }

    BorderRenderer.draw(in: context, geometry: geometry, color: color, style: drawing.style)
    context.flush()
    api.flush(api.connection, id, nil)
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
