import ArgumentParser
import Foundation
import SbordersCore

struct StartCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "start",
    abstract: "Start the border daemon in the foreground."
  )

  @Option(name: .long, help: "Configuration file path.", completion: .file())
  var config: String?

  mutating func validate() throws {
    if config?.isEmpty == true { throw ValidationError("Configuration path must not be empty.") }
  }

  mutating func run() throws {
    let url =
      config.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath).standardizedFileURL }
      ?? ConfigurationFile.defaultURL()

    try MainActor.assumeIsolated {
      let runtime = try BorderRuntime(
        configurationURL: url,
        allowMissingConfiguration: config == nil
      )

      try runtime.run()
    }
  }
}
