import ArgumentParser
import Foundation
import SbordersCore

struct SocketOptions: ParsableArguments {
  @Option(name: .long, help: "Control socket path.")
  var socket: String = LocalSocket.defaultPath

  func send(_ command: String, arguments: [String] = []) throws {
    let response = try ControlClient.request(
      ControlRequest(command: command, arguments: arguments),
      socketPath: (socket as NSString).expandingTildeInPath
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    print(String(decoding: try encoder.encode(response), as: UTF8.self))
    if !response.ok { throw ExitCode.failure }
  }
}
