import ArgumentParser
import Foundation
import SbordersCore

struct ConfigurationOptions: ParsableArguments {
  @Option(name: .long, help: "Configuration file path.", completion: .file())
  var config: String?

  var url: URL {
    config.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath).standardizedFileURL }
      ?? ConfigurationFile.defaultURL()
  }

  mutating func validate() throws {
    if config?.isEmpty == true { throw ValidationError("Configuration path must not be empty.") }
  }
}
