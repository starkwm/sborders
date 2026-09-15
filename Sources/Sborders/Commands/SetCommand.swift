import ArgumentParser

struct SetCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "set",
    abstract: "Change a setting until the next successful reload."
  )

  @OptionGroup var options: SocketOptions
  @Argument(help: "Configuration property.") var property: String
  @Argument(help: "Value; lists use JSON.") var value: String

  mutating func run() throws { try options.send("set", arguments: [property, value]) }
}
