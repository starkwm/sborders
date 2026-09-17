import Foundation
import StarkIPC
import Testing

@testable import SbordersCore

@Test func controlClientAndServerRoundTrip() async throws {
  let directory = try socketDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let path = directory.appending(path: "control.sock").path
  let server = ControlServer(path: path) { request in
    ControlResponse(
      value: .array([.string(request.command)] + request.arguments.map(JSONValue.string))
    )
  }
  try server.start()
  defer { server.stop() }
  let response = try await Task.detached {
    let client = try SocketClient(path: path, serviceName: "sborders")
    try client.send(ControlRequest(command: "query", arguments: ["config"]))
    return try client.receive(ControlResponse.self)
  }.value
  #expect(response.ok)
  #expect(response.value == .array([.string("query"), .string("config")]))
}

@Test(arguments: ["stop", "query"])
func onlySuccessfulStopRepliesTriggerShutdown(command: String) async throws {
  let directory = try socketDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let path = directory.appending(path: "control.sock").path
  await confirmation(expectedCount: command == "stop" ? 1 : 0) { stopped in
    let server = ControlServer(path: path, onStop: { stopped() }) { request in
      ControlResponse(ok: request.arguments.isEmpty, error: request.arguments.first)
    }
    do {
      try server.start()
      defer { server.stop() }
      for arguments in [["rejected"], []] {
        let response = try await Task.detached {
          let client = try SocketClient(path: path, serviceName: "sborders")
          try client.send(ControlRequest(command: command, arguments: arguments))
          return try client.receive(ControlResponse.self)
        }.value
        #expect(response.ok == arguments.isEmpty)
        #expect(response.error == arguments.first)
      }
      // Synchronise with the server queue so the completion callback has finished.
      server.stop()
    } catch {
      Issue.record(error)
    }
  }
}

private func socketDirectory() throws -> URL {
  let directory = URL(fileURLWithPath: "/tmp/sborders-test-" + UUID().uuidString.prefix(8))
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory
}
