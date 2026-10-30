import Foundation
import Testing

@testable import SbordersCore

@Suite("BorderPlacement")
struct BorderPlacementTests {
  @Test("update(from:drawingChanged:orderedIn:forceOrder:): ignores unrelated application metadata")
  func ignoresMetadata() {
    let previous = BorderPlacement(window())
    let next = BorderPlacement(target(processName: "Renamed"))

    #expect(
      next.update(from: previous, drawingChanged: false, orderedIn: true, forceOrder: false)
        == .unchanged
    )
  }

  @Test(
    "update(from:drawingChanged:orderedIn:forceOrder:): movement and ordering reuse prepared surfaces"
  )
  func reusesSurfaces() {
    let previous = BorderPlacement(window())
    var moved = window()
    moved.frame.origin.x += 100
    for next in [
      BorderPlacement(moved), BorderPlacement(target(level: 3)),
      BorderPlacement(target(sublevel: 4)),
    ] {
      #expect(
        next.update(from: previous, drawingChanged: false, orderedIn: true, forceOrder: false)
          == .position
      )
    }
  }

  @Test(
    "update(from:drawingChanged:orderedIn:forceOrder:): drawing and Space changes require preparation"
  )
  func preparesSurfaces() {
    let previous = BorderPlacement(window())
    for next in [BorderPlacement(target(spaces: [2])), BorderPlacement(target(sticky: true))] {
      #expect(
        next.update(from: previous, drawingChanged: false, orderedIn: true, forceOrder: false)
          == .prepare
      )
    }
    #expect(
      previous.update(from: previous, drawingChanged: true, orderedIn: true, forceOrder: false)
        == .prepare
    )
    #expect(
      previous.update(from: previous, drawingChanged: false, orderedIn: false, forceOrder: false)
        == .prepare
    )
    #expect(
      previous.update(from: previous, drawingChanged: false, orderedIn: true, forceOrder: true)
        == .prepare
    )
    #expect(
      previous.update(from: nil, drawingChanged: false, orderedIn: true, forceOrder: false)
        == .prepare
    )
  }
}

private func target(
  processName: String = "Test",
  level: Int32 = 0,
  sublevel: Int32 = 0,
  spaces: [UInt64] = [1],
  sticky: Bool = false
) -> WindowSnapshot {
  let original = window()
  return WindowSnapshot(
    id: original.id,
    pid: original.pid,
    bundleID: original.bundleID,
    processName: processName,
    frame: original.frame,
    level: level,
    sublevel: sublevel,
    spaces: spaces,
    sticky: sticky,
    visible: original.visible,
    fullscreen: original.fullscreen,
    cornerRadius: original.cornerRadius,
    scale: original.scale
  )
}
