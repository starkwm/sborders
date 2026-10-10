import CoreGraphics
import Testing

@testable import SbordersCore

@Suite("BorderRenderer")
struct BorderRendererTests {
  @Test(
    "draw(in:geometry:color:style:tile:): draws the border color and clears the interior",
    arguments: [Configuration.Style.round, .square]
  )
  func drawsOnlyTheBorder(_ style: Configuration.Style) throws {
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
      color: try #require(BorderColor(hex: "#FF008080")),
      style: style
    )

    let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)

    #expect(bytes[21 * 208 + 26 * 4 + 3] == 0)
    #expect(bytes[21 * 208 + 0 * 4 + 3] == 0)
    #expect(abs(Int(bytes[21 * 208 + 3 * 4]) - 128) <= 1)
    #expect(abs(Int(bytes[21 * 208 + 3 * 4 + 2]) - 64) <= 1)
    #expect(abs(Int(bytes[21 * 208 + 3 * 4 + 3]) - 128) <= 1)
  }
}
