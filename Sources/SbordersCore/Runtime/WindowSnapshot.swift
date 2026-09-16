import Foundation

struct WindowSnapshot: Codable, Equatable, Sendable {
  let id: UInt32
  let pid: Int32
  let bundleID: String?
  let processName: String
  var frame: CGRect
  let level: Int32
  let sublevel: Int32
  let spaces: [UInt64]
  let sticky: Bool
  var visible: Bool
  let fullscreen: Bool
  let cornerRadius: Double
  let scale: Double
}

enum WindowEligibility {
  static func accepts(parent: UInt32, attributes: UInt64, tags: UInt64) -> Bool {
    guard parent == 0, tags & (1 << 7) == 0, tags & (1 << 18) == 0 else { return false }
    let drawable = attributes & 2 != 0 || tags & 0x400_0000_0000_0000 != 0
    let document = tags & 1 != 0
    let modal = tags & 2 != 0 && tags & (1 << 31) != 0
    return drawable && (document || modal)
  }
}
