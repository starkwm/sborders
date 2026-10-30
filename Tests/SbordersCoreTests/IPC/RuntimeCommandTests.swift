import StarkIPC
import Testing

@testable import SbordersCore

@Suite("RuntimeCommand")
struct RuntimeCommandTests {
  @Test("init(_:): parses supported commands and the default query")
  func parsesCommands() throws {
    #expect(try RuntimeCommand(ControlRequest(command: "query")) == .query(.diagnostics))
    for subject in ["config", "windows", "diagnostics"] {
      #expect(
        try RuntimeCommand(ControlRequest(command: "query", arguments: [subject]))
          == .query(RuntimeCommand.Subject(rawValue: subject)!)
      )
    }
    #expect(try RuntimeCommand(ControlRequest(command: "reload")) == .reload)
    #expect(try RuntimeCommand(ControlRequest(command: "stop")) == .stop)
    #expect(
      try RuntimeCommand(ControlRequest(command: "set", arguments: ["width", "6"]))
        == .set("width", "6")
    )
  }

  @Test("init(_:): rejects invalid requests with existing error messages")
  func rejectsInvalidRequests() {
    let cases: [(ControlRequest, String)] = [
      (ControlRequest(command: "stop", arguments: ["extra"]), "stop does not accept arguments."),
      (
        ControlRequest(command: "reload", arguments: ["extra"]), "reload does not accept arguments."
      ),
      (
        ControlRequest(command: "query", arguments: ["config", "windows"]),
        "Choose one query subject."
      ),
      (ControlRequest(command: "query", arguments: ["unknown"]), "Unknown query: unknown."),
      (ControlRequest(command: "set", arguments: ["width"]), "set requires a property and value."),
      (
        ControlRequest(command: "set", arguments: ["width", "6", "extra"]),
        "set requires a property and value."
      ),
      (ControlRequest(command: "unknown"), "Unknown command: unknown."),
      (
        ControlRequest(command: "query", value: .string("extra")),
        "This command does not accept a value payload."
      ),
    ]
    for (request, message) in cases {
      do {
        _ = try RuntimeCommand(request)
        Issue.record("Accepted invalid request: \(request.command)")
      } catch {
        #expect(error.localizedDescription == message)
      }
    }
  }
}
