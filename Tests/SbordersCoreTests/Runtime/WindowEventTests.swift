import Foundation
import Testing

@testable import SbordersCore

@Suite("WindowEvent")
struct WindowEventTests {
  @Test("decode(code:data:count:): recognizes Mission Control entry")
  func decodesMissionControlEntry() {
    #expect(
      WindowEvent.decode(code: 1204, data: nil, count: 0)
        == WindowEvent(kind: .missionControl, windowID: nil)
    )
  }

  @Test("decode(code:data:count:): handles unaligned data") func decodesUnalignedEvents() {
    let bytes: [UInt8] = [255, 0, 0, 0, 0, 0, 0, 0, 0, 42, 0, 0, 0]

    bytes.withUnsafeBytes { raw in
      let pointer = raw.baseAddress!.advanced(by: 1)

      #expect(WindowEvent.decode(code: 1325, data: pointer, count: 11) == nil)
      #expect(WindowEvent.decode(code: 1325, data: pointer, count: 12)?.windowID == 42)
      #expect(WindowEvent.decode(code: 804, data: pointer, count: 0) == nil)
    }

    #expect(WindowEvent.decode(code: 1508, data: nil, count: 0)?.kind == .focus)
  }

  @Test("decode(code:data:count:): maps event codes to kinds") func decodesEventKinds() {
    let cases: [(UInt32, WindowEvent.Kind)] = [
      (804, .closed), (806, .moved), (807, .resized), (808, .changed),
      (811, .changed), (815, .changed), (816, .hidden), (1322, .focus),
      (723, .focus), (1325, .created), (1326, .removedFromSpace),
    ]

    for (code, kind) in cases {
      let words: [UInt32] = code == 1325 || code == 1326 ? [0, 0, 42] : [42]

      words.withUnsafeBytes { bytes in
        let event = WindowEvent.decode(code: code, data: bytes.baseAddress, count: bytes.count)

        #expect(event == WindowEvent(kind: kind, windowID: 42))
      }
    }
  }
}
