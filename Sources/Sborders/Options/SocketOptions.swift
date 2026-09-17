import ArgumentParser
import Foundation
import StarkIPC

struct SocketOptions: ParsableArguments {
  @Option(name: .long, help: "Control socket path.")
  var socket: String = NSHomeDirectory() + "/.config/sborders/control.sock"

  func send(_ command: String, arguments: [String] = []) throws {
    let client = try SocketClient(
      path: (socket as NSString).expandingTildeInPath,
      serviceName: "sborders"
    )
    try client.send(ControlRequest(command: command, arguments: arguments))
    let response = try client.receive(ControlResponse.self)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    print(String(decoding: try encoder.encode(response), as: UTF8.self))
    if !response.ok { throw ExitCode.failure }
  }
}
