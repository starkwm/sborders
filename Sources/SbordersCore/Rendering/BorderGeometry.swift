import CoreGraphics

struct BorderGeometry: Equatable {
  let frame: CGRect
  let inner: CGRect
  let outer: CGRect
  let radius: Double
  let width: Double

  init?(target: CGRect, width: Double, radius: Double) {
    guard
      [target.minX, target.minY, target.width, target.height, width, radius].allSatisfy(\.isFinite),
      target.width >= 2, target.height >= 2, width > 0
    else { return nil }

    let padding = width + 2
    frame = target.insetBy(dx: -padding, dy: -padding)
    inner = CGRect(origin: CGPoint(x: padding, y: padding), size: target.size)
    outer = inner.insetBy(dx: -width, dy: -width)
    self.radius = max(0, min(radius, min(target.width, target.height) / 2))
    self.width = width
  }

  /// Nonoverlapping rectangles in drawing coordinates. Horizontal strips include
  /// the rounded corners; the side strips only need to cover the straight edges.
  func tiles(scale: Double, style: Configuration.Style) -> [CGRect] {
    let scale = scale.isFinite && scale > 0 ? scale : 1
    let corner = style == .round ? radius : 0
    let band = ceil((inner.minY + corner) * scale) / scale
    let bottom = min(band, frame.height)
    let top = max(bottom, floor((frame.height - band) * scale) / scale)
    let left = min(ceil(inner.minX * scale) / scale, frame.width)
    let right = max(left, floor((frame.width - inner.minX) * scale) / scale)

    return [
      CGRect(x: 0, y: 0, width: frame.width, height: bottom),
      CGRect(x: 0, y: top, width: frame.width, height: frame.height - top),
      CGRect(x: 0, y: bottom, width: left, height: top - bottom),
      CGRect(x: right, y: bottom, width: frame.width - right, height: top - bottom),
    ].filter { $0.width > 0 && $0.height > 0 }
  }

  /// WindowServer has a top-left origin; drawing contexts have a bottom-left origin.
  func screenFrame(for tile: CGRect) -> CGRect {
    CGRect(
      x: frame.minX + tile.minX,
      y: frame.maxY - tile.maxY,
      width: tile.width,
      height: tile.height
    )
  }
}
