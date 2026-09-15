import ArgumentParser

struct ReloadCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "reload",
    abstract: "Reload the file and clear runtime overrides."
  )

  @OptionGroup var options: SocketOptions

  mutating func run() throws { try options.send("reload") }
}
