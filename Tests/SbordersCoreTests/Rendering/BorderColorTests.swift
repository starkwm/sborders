import CoreGraphics
import Testing

@testable import SbordersCore

@Suite("BorderColor")
struct BorderColorTests {
  @Test("init(hex:): reads alpha as the last component") func coloursUseAlphaLast() throws {
    let color = try #require(BorderColor(hex: "#FF008080"))

    #expect(color.red == 1)
    #expect(color.green == 0)
    #expect(color.blue == 128.0 / 255)
    #expect(color.alpha == 128.0 / 255)
    #expect(BorderColor(hex: "#ffffff")?.alpha == 1)
    #expect(BorderColor(hex: "#12zz34") == nil)
  }
}
