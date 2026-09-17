import StarkIPC

public enum ControlClient {
  public static func request(_ request: ControlRequest, socketPath: String) throws
    -> ControlResponse
  {
    let client = try SocketClient(path: socketPath, serviceName: "sborders")
    try client.send(request)
    return try client.receive(ControlResponse.self)
  }
}
