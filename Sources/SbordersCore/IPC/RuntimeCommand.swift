import StarkIPC

enum RuntimeCommand: Equatable {
  enum Subject: String { case config, windows, diagnostics }

  case query(Subject)
  case reload
  case set(String, String)
  case stop

  init(_ request: ControlRequest) throws {
    guard request.value == nil else {
      throw MessageError.message("This command does not accept a value payload.")
    }

    switch request.command {
    case "query":
      guard request.arguments.count <= 1 else {
        throw MessageError.message("Choose one query subject.")
      }

      let name = request.arguments.first ?? "diagnostics"
      guard let subject = Subject(rawValue: name) else {
        throw MessageError.message("Unknown query: \(name).")
      }

      self = .query(subject)
    case "reload", "stop":
      guard request.arguments.isEmpty else {
        throw MessageError.message("\(request.command) does not accept arguments.")
      }

      self = request.command == "reload" ? .reload : .stop
    case "set":
      guard request.arguments.count == 2 else {
        throw MessageError.message("set requires a property and value.")
      }

      self = .set(request.arguments[0], request.arguments[1])
    default: throw MessageError.message("Unknown command: \(request.command).")
    }
  }
}
