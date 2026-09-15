import ArgumentParser

@main
struct Sborders: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sborders",
    abstract: "Window borders for macOS.",
    version: Version.current,
    subcommands: [
      StartCommand.self, ValidateCommand.self, QueryCommand.self, ReloadCommand.self,
      SetCommand.self, StopCommand.self,
    ],
    defaultSubcommand: StartCommand.self
  )
}
