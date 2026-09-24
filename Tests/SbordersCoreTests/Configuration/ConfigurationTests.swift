import Foundation
import Testing

@testable import SbordersCore

@Suite("Configuration")
struct ConfigurationTests {
  @Test("setting(_:value:): validates settings") func validatesSettings() throws {
    let original = Configuration()

    #expect(throws: (any Error).self) { try original.setting("width", value: "-2") }
    #expect(try original.setting("activeColor", value: "#ABCDEF80").activeColor == "#ABCDEF80")
    #expect(try original.setting("enabled", value: "false").enabled == false)
  }

  @Test("setting(_:value:): rejects duplicate matcher keys") func rejectsDuplicateMatcherKeys() {
    #expect(throws: (any Error).self) {
      try Configuration().setting("includeApps", value: #"[{"bundleID":"a","bundleID":"b"}]"#)
    }
  }
}
