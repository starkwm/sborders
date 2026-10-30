import ArgumentParser
import Foundation
import SbordersCore

struct ValidateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "validate",
    abstract: "Check configuration without starting the daemon."
  )

  @OptionGroup var options: ConfigurationOptions

  mutating func run() throws {
    try ConfigurationFile.validate(url: options.url)
    print("Configuration is valid.")
  }
}
