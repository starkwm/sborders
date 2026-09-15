import CoreGraphics

struct BorderColor: Equatable, Sendable {
  let red: Double
  let green: Double
  let blue: Double
  let alpha: Double

  var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }

  init?(hex: String) {
    guard hex.first == "#", [7, 9].contains(hex.utf8.count),
      let value = UInt32(hex.dropFirst(), radix: 16)
    else { return nil }
    let rgba = hex.utf8.count == 7 ? (value << 8) | 255 : value
    red = Double((rgba >> 24) & 255) / 255
    green = Double((rgba >> 16) & 255) / 255
    blue = Double((rgba >> 8) & 255) / 255
    alpha = Double(rgba & 255) / 255
  }
}
