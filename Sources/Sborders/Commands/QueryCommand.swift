import ArgumentParser

struct QueryCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "query",
    abstract: "Inspect windows, configuration, or diagnostics as JSON."
  )

  @OptionGroup var options: SocketOptions
  @Flag(name: .long) var windows = false
  @Flag(name: .long) var config = false
  @Flag(name: .long) var diagnostics = false

  mutating func validate() throws {
    guard [windows, config, diagnostics].filter({ $0 }).count <= 1 else {
      throw ValidationError("Choose one query subject.")
    }
  }

  mutating func run() throws {
    try options.send("query", arguments: [windows ? "windows" : config ? "config" : "diagnostics"])
  }
}
