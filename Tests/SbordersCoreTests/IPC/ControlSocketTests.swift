import Darwin
import Foundation
import Testing

@testable import SbordersCore

private func socketDirectory() throws -> URL {
  let directory = URL(fileURLWithPath: "/tmp/sborders-test-" + UUID().uuidString.prefix(8))
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory
}

@Test func roundTripAndExclusiveOwnership() async throws {
  let directory = try socketDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let path = directory.appending(path: "control.sock").path
  let server = ControlServer(path: path) { request in
    ControlResponse(value: .string(request.command))
  }
  try server.start()
  defer { server.stop() }
  let duplicate = ControlServer(path: path) { _ in ControlResponse() }
  #expect(throws: (any Error).self) { try duplicate.start() }
  let response = try await Task.detached {
    try ControlClient.request(ControlRequest(command: "hello"), socketPath: path)
  }.value
  #expect(response.ok)
  if case .string(let value) = response.value {
    #expect(value == "hello")
  } else {
    Issue.record("Missing response")
  }
  var info = stat()
  #expect(lstat(path, &info) == 0)
  #expect(info.st_mode & 0o777 == 0o600)
  server.stop()
  #expect(!FileManager.default.fileExists(atPath: path))
}

@Test func refusesToReplaceAnExistingFile() throws {
  let directory = try socketDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let path = directory.appending(path: "control.sock")
  try Data("keep".utf8).write(to: path)
  let server = ControlServer(path: path.path) { _ in ControlResponse() }
  #expect(throws: (any Error).self) { try server.start() }
  #expect(try String(contentsOf: path, encoding: .utf8) == "keep")
}

@Test func acceptsSplitRequestsAndRejectsMalformedJSON() async throws {
  let directory = try socketDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let path = directory.appending(path: "control.sock").path
  let server = ControlServer(path: path) { _ in ControlResponse() }
  try server.start()
  defer { server.stop() }
  for payload in [#"{"command":"query","arguments":[]}"#, "{broken}"] {
    let ok = try await Task.detached {
      let fd = try LocalSocket.connect(path: path)
      defer { close(fd) }
      var timeout = timeval(tv_sec: 2, tv_usec: 0)
      setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
      let bytes = Data(payload.utf8)
      try LocalSocket.send(bytes.prefix(2), to: fd)
      try LocalSocket.send(bytes.dropFirst(2) + Data([10]), to: fd)
      var data = Data()
      var buffer = [UInt8](repeating: 0, count: 4096)
      while !data.contains(10) {
        let count = recv(fd, &buffer, buffer.count, 0)
        guard count > 0 else { throw MessageError.message("No response") }
        data.append(contentsOf: buffer.prefix(count))
      }
      return try JSONDecoder().decode(ControlResponse.self, from: data).ok
    }.value
    #expect(ok == !payload.contains("broken"))
  }
}

@Test func rejectsOversizedSocketPathsAndEmbeddedNulls() {
  #expect(throws: (any Error).self) {
    try LocalSocket.address(String(repeating: "x", count: 200)) { _, _ in }
  }
  #expect(throws: (any Error).self) { try LocalSocket.address("/tmp/test\0ignored") { _, _ in } }
}

@Test func shutdownDoesNotDeleteAReplacementFile() throws {
  let directory = try socketDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let path = directory.appending(path: "control.sock")
  let server = ControlServer(path: path.path) { _ in ControlResponse() }
  try server.start()
  defer { server.stop() }
  try FileManager.default.removeItem(at: path)
  try Data("replacement".utf8).write(to: path)
  server.stop()
  #expect(try String(contentsOf: path, encoding: .utf8) == "replacement")
}
