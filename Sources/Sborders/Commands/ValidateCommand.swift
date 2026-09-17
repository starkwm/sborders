import ArgumentParser
import Foundation
import SbordersCore

struct ValidateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "validate",
    abstract: "Check configuration without starting the daemon."
  )

  @Option(name: .long, help: "Configuration file path.", completion: .file())
  var config: String?

  mutating func validate() throws {
    if config?.isEmpty == true { throw ValidationError("Configuration path must not be empty.") }
  }

  mutating func run() throws {
    let url =
      config.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
      ?? ConfigurationFile.defaultURL()

    try ConfigurationFile.validate(url: url)
    print("Configuration is valid.")
  }
}
