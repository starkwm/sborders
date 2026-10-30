import ArgumentParser
import Foundation
import SbordersCore

struct StartCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "start",
    abstract: "Start the border daemon in the foreground."
  )

  @OptionGroup var options: ConfigurationOptions

  mutating func run() throws {
    try MainActor.assumeIsolated {
      let runtime = try BorderRuntime(
        configurationURL: options.url,
        allowMissingConfiguration: options.config == nil
      )

      try runtime.run()
    }
  }
}
