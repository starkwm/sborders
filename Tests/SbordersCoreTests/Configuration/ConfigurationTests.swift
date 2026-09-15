import Foundation
import Testing

@testable import SbordersCore

private func decode(_ text: String) throws -> Configuration {
  try ConfigurationDecoder.decode(from: Data(text.utf8))
}

@Test func decodesDefaults() throws {
  #expect(try decode("{}") == Configuration())
}

@Test func jsoncKeepsStringsAndAllowsCommentsAndTrailingCommas() throws {
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

@Test(arguments: [
  #"{"width":4,"width":5}"#,
  #"{"width":4,"\u0077idth":5}"#,
  #"{"includeApps":[{"bundleID":"a","bundleID":"b"}]}"#,
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
  #"{"width":4,,}"#,
  #"{"width":,}"#,
  #"{/* unclosed"#,
  #"[]"#,
])
func rejectsInvalidConfiguration(_ json: String) {
  #expect(throws: (any Error).self) { try decode(json) }
}

@Test func identicalKeysInDifferentObjectsAreAllowed() throws {
  let config = try decode(#"{"includeApps":[{"bundleID":"a"},{"bundleID":"b"}]}"#)
  #expect(config.includeApps.count == 2)
}

@Test func runtimeSettingsValidateBeforeChangingState() throws {
  let original = Configuration()
  #expect(throws: (any Error).self) { try original.setting("width", value: "-2") }
  #expect(original.width == 4)
  #expect(try original.setting("activeColor", value: "#ABCDEF80").activeColor == "#ABCDEF80")
  #expect(try original.setting("enabled", value: "false").enabled == false)
}

@Test @MainActor func failedReloadRetainsSettingsAndSuccessfulReloadClearsOverrides() throws {
  let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let url = directory.appending(path: "config.json")
  try Data(#"{"width":5}"#.utf8).write(to: url)
  let store = try ConfigurationStore(url: url, allowMissing: false)
  try store.set("width", value: "6")
  try Data(#"{"width":-1}"#.utf8).write(to: url)
  #expect(throws: (any Error).self) { try store.reload() }
  #expect(store.configuration.width == 6)
  #expect(store.hasOverrides)
  #expect(store.lastError != nil)
  try Data(#"{"width":7}"#.utf8).write(to: url, options: .atomic)
  try store.reload()
  #expect(store.configuration.width == 7)
  #expect(!store.hasOverrides)
  #expect(store.lastError == nil)
}

@Test @MainActor func missingDefaultAndExplicitFilesDiffer() throws {
  let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")
  #expect(try ConfigurationStore(url: url, allowMissing: true).configuration == Configuration())
  #expect(throws: (any Error).self) { try ConfigurationStore(url: url, allowMissing: false) }
  #expect(throws: (any Error).self) { try ConfigurationFile.validate(url: url) }
}

@Test func jsoncPathTakesPrecedenceEvenWhenInvalid() throws {
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

@Test func runtimeMatcherValuesRejectDuplicateKeys() {
  #expect(throws: (any Error).self) {
    try Configuration().setting("includeApps", value: #"[{"bundleID":"a","bundleID":"b"}]"#)
  }
}
