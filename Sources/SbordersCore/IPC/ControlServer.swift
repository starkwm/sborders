import Foundation
import StarkIPC

final class ControlServer: Sendable {
  private let server: SocketServer<ControlRequest, ControlResponse>

  init(
    path: String,
    onStop: @escaping @Sendable () -> Void = {},
    handler: @escaping @Sendable (ControlRequest) async -> ControlResponse
  ) {
    server = SocketServer(
      path: path,
      serviceName: "sborders",
      errorResponse: { ControlResponse(ok: false, error: $0.localizedDescription) },
      handler: { request in
        let response = await handler(request)

        return SocketReply(
          response,
          onComplete: {
            if request.command == "stop" && response.ok { onStop() }
          }
        )
      }
    )
  }

  func start() throws { try server.start() }

  func stop() { server.stop() }
}
