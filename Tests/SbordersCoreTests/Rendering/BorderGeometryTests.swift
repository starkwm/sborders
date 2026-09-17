import CoreGraphics
import Testing

@testable import SbordersCore

@Test func geometryPreservesTargetCutoutAcrossNegativeCoordinates() throws {
  let target = CGRect(x: -1000, y: -200, width: 400, height: 300)
  let geometry = try #require(BorderGeometry(target: target, width: 4, radius: 16))

  #expect(geometry.frame == CGRect(x: -1006, y: -206, width: 412, height: 312))
  #expect(geometry.inner.offsetBy(dx: geometry.frame.minX, dy: geometry.frame.minY) == target)
  #expect(geometry.outer.width == 408)
}

@Test func tinyGeometryAndInvalidFramesAreHandled() throws {
  #expect(
    BorderGeometry(target: CGRect(x: 0, y: 0, width: 1, height: 1), width: 4, radius: 16) == nil
  )

  #expect(
    BorderGeometry(
      target: CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 5),
      width: 4,
      radius: 16
    )
      == nil
  )

  #expect(
    try #require(
      BorderGeometry(target: CGRect(x: 0, y: 0, width: 8, height: 10), width: 4, radius: 16)
    ).radius == 4
  )
}

@Test func coloursUseAlphaLast() throws {
  let color = try #require(BorderColor(hex: "#FF008080"))

  #expect(color.red == 1)
  #expect(color.green == 0)
  #expect(color.blue == 128.0 / 255)
  #expect(color.alpha == 128.0 / 255)
  #expect(BorderColor(hex: "#ffffff")?.alpha == 1)
  #expect(BorderColor(hex: "#12zz34") == nil)
}

@Test(arguments: [Configuration.Style.round, .square])
func rendererLeavesTheWindowInteriorAndPaddingTransparent(_ style: Configuration.Style) throws {
  let geometry = try #require(
    BorderGeometry(target: CGRect(x: 0, y: 0, width: 40, height: 30), width: 4, radius: 8)
  )
  let context = try #require(
    CGContext(
      data: nil,
      width: 52,
      height: 42,
      bitsPerComponent: 8,
      bytesPerRow: 208,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
  )
  BorderRenderer.draw(
    in: context,
    geometry: geometry,
    color: try #require(BorderColor(hex: "#FF0000")),
    style: style
  )
  let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)

  #expect(bytes[21 * 208 + 26 * 4 + 3] == 0)
  #expect(bytes[21 * 208 + 0 * 4 + 3] == 0)
  #expect(bytes[21 * 208 + 3 * 4] == 255)
  #expect(bytes[21 * 208 + 3 * 4 + 3] == 255)
}
