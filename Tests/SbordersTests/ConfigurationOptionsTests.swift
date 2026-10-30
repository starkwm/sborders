import Foundation
import Testing

@testable import Sborders

@Suite("ConfigurationOptions")
struct ConfigurationOptionsTests {
  @Test("url: start and validate resolve explicit paths consistently")
  func resolvesPaths() throws {
    let path = "~/sborders/../config.json"
    let start = try StartCommand.parse(["--config", path])
    let validate = try ValidateCommand.parse(["--config", path])
    let expected = FileManager.default.homeDirectoryForCurrentUser.appending(path: "config.json")

    #expect(start.options.url == expected)
    #expect(validate.options.url == expected)
    #expect(start.options.config != nil)
    #expect(try StartCommand.parse([]).options.config == nil)
  }

  @Test("validate(): both commands reject empty configuration paths")
  func rejectsEmptyPaths() {
    #expect(throws: (any Error).self) { try StartCommand.parse(["--config", ""]) }
    #expect(throws: (any Error).self) { try ValidateCommand.parse(["--config", ""]) }
  }
}
