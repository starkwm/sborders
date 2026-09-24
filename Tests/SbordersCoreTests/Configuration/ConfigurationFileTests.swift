import Foundation
import Testing

@testable import SbordersCore

@Suite("ConfigurationFile")
struct ConfigurationFileTests {
  @Test("defaultURL(directory:): prefers JSONC") func prefersJSONC() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let jsonc = directory.appending(path: "config.jsonc")
    try Data("invalid".utf8).write(to: jsonc)
    try Data("{}".utf8).write(to: directory.appending(path: "config.json"))

    #expect(ConfigurationFile.defaultURL(directory: directory) == jsonc)
    #expect(throws: (any Error).self) {
      try ConfigurationFile.validate(url: ConfigurationFile.defaultURL(directory: directory))
    }
  }

  @Test("validate(url:): rejects a missing file")
  func rejectsMissingFile() {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")

    #expect(throws: (any Error).self) { try ConfigurationFile.validate(url: url) }
  }

  @Test("decode(_:): uses defaults for omitted values") func decodesDefaults() throws {
    #expect(try decode("{}") == Configuration())
  }

  @Test("decode(_:): accepts JSONC") func decodesJSONC() throws {
    let config = try decode(
      #"""
      {
        // A normal comment.
        "width": 5, /* between values */
        "excludeApps": [{"processName": "https://example.test/*name*/",},],
      }
      """#
    )

    #expect(config.width == 5)
    #expect(config.excludeApps.first?.processName == "https://example.test/*name*/")
  }

  @Test(
    "decode(_:): rejects invalid configuration",
    arguments: [
      #"{"width":4,"width":5}"#,
      #"{"widht":4}"#,
      #"{"width":null}"#,
      #"{"$schema":null}"#,
      #"{"width":-1}"#,
      #"{"width":65}"#,
      #"{"width":1e999}"#,
      #"{"enabled":"true"}"#,
      #"{"style":"triangle"}"#,
      #"{"activeColor":"0xff000000"}"#,
      #"{"includeApps":[{"bundleID":"a","processName":"b"}]}"#,
      #"{"includeApps":[{"bundleID":""}]}"#,
      #"{"includeApps":[{"bundleID":null}]}"#,
      #"{"includeApps":[{"bundleId":"a"}]}"#,
      #"[]"#,
    ]
  )
  func rejectsInvalidConfiguration(_ json: String) {
    #expect(throws: (any Error).self) { try decode(json) }
  }
}

private func decode(_ text: String) throws -> Configuration {
  try ConfigurationFile.decode(Data(text.utf8))
}
