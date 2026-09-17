import CoreGraphics

/// Draws the ring into either a WindowServer context or an offscreen test bitmap.
enum BorderRenderer {
  static func draw(
    in context: CGContext,
    geometry: BorderGeometry,
    color: BorderColor,
    style: Configuration.Style
  ) {
    context.saveGState()
    context.clear(CGRect(origin: .zero, size: geometry.frame.size))
    let path = CGMutablePath()

    if style == .round {
      path.addRoundedRect(
        in: geometry.outer,
        cornerWidth: geometry.radius + geometry.width,
        cornerHeight: geometry.radius + geometry.width
      )
      path.addRoundedRect(
        in: geometry.inner,
        cornerWidth: geometry.radius,
        cornerHeight: geometry.radius
      )
    } else {
      path.addRect(geometry.outer)
      path.addRect(geometry.inner)
    }

    context.addPath(path)
    context.setFillColor(color.cgColor)
    context.drawPath(using: .eoFill)
    context.restoreGState()
  }
}
