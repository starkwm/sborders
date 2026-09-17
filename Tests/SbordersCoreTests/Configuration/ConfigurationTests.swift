import Foundation
import Testing

@testable import SbordersCore

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
])
func rejectsInvalidConfiguration(_ json: String) {
  #expect(throws: (any Error).self) { try decode(json) }
}

@Test func runtimeSettingsValidateBeforeChangingState() throws {
  let original = Configuration()

  #expect(throws: (any Error).self) { try original.setting("width", value: "-2") }
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

  let store = try ConfigurationStore(url: url, allowMissing: true)

  #expect(store.configuration == Configuration())
  #expect(try !store.reload(ifChanged: true))
  #expect(store.lastError == nil)
  #expect(throws: (any Error).self) { try ConfigurationStore(url: url, allowMissing: false) }
  #expect(throws: (any Error).self) { try ConfigurationFile.validate(url: url) }
}

@Test @MainActor func unchangedFilePreservesOverrides() throws {
  let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")
  try Data(#"{"width":5}"#.utf8).write(to: url)
  defer { try? FileManager.default.removeItem(at: url) }

  let store = try ConfigurationStore(url: url, allowMissing: false)
  try store.set("width", value: "6")

  #expect(try !store.reload(ifChanged: true))
  #expect(store.configuration.width == 6)
  #expect(store.hasOverrides)

  #expect(try store.reload())
  #expect(store.configuration.width == 5)
  #expect(!store.hasOverrides)
}

@Test @MainActor func restoredFileClearsReloadError() throws {
  let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")
  let original = Data(#"{"width":5}"#.utf8)
  try original.write(to: url)
  defer { try? FileManager.default.removeItem(at: url) }

  let store = try ConfigurationStore(url: url, allowMissing: false)
  try store.set("width", value: "6")
  try Data(#"{"width":-1}"#.utf8).write(to: url)

  #expect(throws: (any Error).self) { try store.reload(ifChanged: true) }
  #expect(store.lastError != nil)
  #expect(store.configuration.width == 6)
  #expect(store.hasOverrides)

  try original.write(to: url)

  #expect(try store.reload(ifChanged: true))
  #expect(store.lastError == nil)
  #expect(store.configuration.width == 5)
  #expect(!store.hasOverrides)
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

@Test @MainActor func rejectedRuntimeSettingRetainsConfigurationAndOverrides() throws {
  let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")
  let store = try ConfigurationStore(url: url, allowMissing: true)
  for hasOverrides in [false, true] {
    if hasOverrides { try store.set("width", value: "6") }
    let original = store.configuration

    #expect(throws: MessageError.self) {
      try store.set("focusMode", value: "accessibility") { candidate in
        #expect(candidate.focusMode == .accessibility)
        #expect(store.configuration == original)

        throw MessageError.message("Permission denied.")
      }
    }

    #expect(store.configuration == original)
    #expect(store.hasOverrides == hasOverrides)
  }
  try store.set("width", value: "7") { candidate in
    #expect(candidate.width == 7)
    #expect(store.configuration.width == 6)
  }

  #expect(store.configuration.width == 7)
  #expect(store.hasOverrides)
}

private func decode(_ text: String) throws -> Configuration {
  try ConfigurationFile.decode(Data(text.utf8))
}
