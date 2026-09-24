import Foundation
import StarkIPC
import Testing

@testable import SbordersCore

@Suite("ControlServer")
struct ControlServerTests {
  @Test(
    "init(path:onStop:handler:): stops only after a successful stop response",
    arguments: ["stop", "query"]
  )
  func stopsOnlyAfterSuccessfulStop(command: String) async throws {
    let directory = try socketDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let path = directory.appending(path: "control.sock").path

    try await confirmation(expectedCount: command == "stop" ? 1 : 0) { stopped in
      let server = ControlServer(path: path, onStop: { stopped() }) { request in
        ControlResponse(ok: request.arguments.isEmpty, error: request.arguments.first)
      }

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
    }
  }
}

private func socketDirectory() throws -> URL {
  let directory = URL(fileURLWithPath: "/tmp/sborders-test-" + UUID().uuidString.prefix(8))
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

  return directory
}
