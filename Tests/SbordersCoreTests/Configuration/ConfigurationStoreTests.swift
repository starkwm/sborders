import Foundation
import Testing

@testable import SbordersCore

@Suite("ConfigurationStore")
@MainActor
struct ConfigurationStoreTests {
  @Test("init(url:allowMissing:): follows the missing file policy")
  func missingFilePolicy() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")

    let store = try ConfigurationStore(url: url, allowMissing: true)

    #expect(store.configuration == Configuration())
    #expect(try !store.reload(ifChanged: true))
    #expect(store.lastError == nil)
    #expect(throws: (any Error).self) { try ConfigurationStore(url: url, allowMissing: false) }
  }

  @Test("reload(ifChanged:validate:): preserves settings after an invalid file")
  func reloadPreservesValidSettings() throws {
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

  @Test("reload(ifChanged:validate:): unchanged files preserve overrides")
  func unchangedFilePreservesOverrides() throws {
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

  @Test("reload(ifChanged:validate:): a restored file clears the error")
  func restoredFileClearsReloadError() throws {
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

  @Test("set(_:value:validate:): rejected settings preserve overrides")
  func rejectedSettingPreservesOverrides() throws {
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
}
