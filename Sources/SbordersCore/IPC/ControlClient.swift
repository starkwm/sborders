import Darwin
import Foundation

public enum ControlClient {
  public static func request(_ request: ControlRequest, socketPath: String) throws
    -> ControlResponse
  {
    let fd = try LocalSocket.connect(path: socketPath)
    defer { close(fd) }
    var timeout = timeval(tv_sec: 5, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    var data = try JSONEncoder().encode(request)
    data.append(10)
    try LocalSocket.send(data, to: fd)
    var pending = Data()
    var buffer = [UInt8](repeating: 0, count: 8192)
    while true {
      let count = recv(fd, &buffer, buffer.count, 0)
      if count < 0 && errno == EINTR { continue }
      guard count > 0 else { throw MessageError.message("Connection closed or timed out.") }
      pending.append(contentsOf: buffer.prefix(count))
      guard pending.count <= 1_048_576 else { throw MessageError.message("Response too large.") }
      if let newline = pending.firstIndex(of: 10) {
        return try JSONDecoder().decode(ControlResponse.self, from: pending.prefix(upTo: newline))
      }
    }
  }
}
