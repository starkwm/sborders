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

@Test(arguments: [Configuration.Style.round, .square], [1.0, 2.0])
func tiledRendererMatchesFullWindowPixels(style: Configuration.Style, scale: Double) throws {
  for size in [
    CGSize(width: 80, height: 60), CGSize(width: 80.25, height: 60.75),
    CGSize(width: 8, height: 10),
  ] {
    for width in [0.5, 4.0, 5.25, 64.0] {
      let geometry = try #require(
        BorderGeometry(
          target: CGRect(origin: CGPoint(x: -100, y: -200), size: size),
          width: width,
          radius: 9
        )
      )
      let full = try bitmap(size: geometry.frame.size, scale: scale)
      let color = try #require(BorderColor(hex: "#FF008080"))
      BorderRenderer.draw(in: full, geometry: geometry, color: color, style: style)
      var assembled = [UInt8](repeating: 0, count: full.bytesPerRow * full.height)
      let tiles = geometry.tiles(scale: scale, style: style)
      var union = CGRect.null

      for (index, tile) in tiles.enumerated() {
        #expect(tile.width > 0 && tile.height > 0)
        #expect(CGRect(origin: .zero, size: geometry.frame.size).contains(tile))
        for other in tiles.dropFirst(index + 1) {
          let intersection = tile.intersection(other)
          #expect(intersection.isNull || intersection.width == 0 || intersection.height == 0)
        }
        union = union.union(geometry.screenFrame(for: tile))

        let context = try bitmap(size: tile.size, scale: scale)
        BorderRenderer.draw(in: context, geometry: geometry, color: color, style: style, tile: tile)
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let x = Int((tile.minX * scale).rounded())
        let y = full.height - Int((tile.minY * scale).rounded()) - context.height

        for row in 0..<context.height {
          for column in 0..<context.width * 4 {
            assembled[(y + row) * full.bytesPerRow + x * 4 + column] =
              bytes[row * context.bytesPerRow + column]
          }
        }
      }

      #expect(union == geometry.frame)
      let expected = try #require(full.data).assumingMemoryBound(to: UInt8.self)
      // Clipping can change CoreGraphics colour-channel rounding by one byte.
      let differences = assembled.indices.filter { abs(Int(assembled[$0]) - Int(expected[$0])) > 1 }
      #expect(
        differences.isEmpty,
        "size=\(size), width=\(width), first differences=\(differences.prefix(8))"
      )
    }
  }
}

@Test func largeWindowTilesExcludeMostOfTheEmptyInterior() throws {
  let geometry = try #require(
    BorderGeometry(target: CGRect(x: 0, y: 0, width: 1500, height: 1000), width: 4, radius: 9)
  )
  let tiles = geometry.tiles(scale: 2, style: .round)
  let area = tiles.reduce(0) { $0 + $1.width * $1.height }

  #expect(tiles.count == 4)
  #expect(area < geometry.frame.width * geometry.frame.height * 0.04)
}

private func bitmap(size: CGSize, scale: Double) throws -> CGContext {
  let width = Int(ceil(size.width * scale))
  let height = Int(ceil(size.height * scale))
  let context = try #require(
    CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
  )
  context.scaleBy(x: scale, y: scale)
  return context
}
