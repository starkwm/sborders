import ArgumentParser

struct StopCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "stop",
    abstract: "Stop the daemon and remove its borders."
  )

  @OptionGroup var options: SocketOptions

  mutating func run() throws { try options.send("stop") }
}
