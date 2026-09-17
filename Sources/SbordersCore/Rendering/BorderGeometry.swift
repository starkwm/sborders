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
}
