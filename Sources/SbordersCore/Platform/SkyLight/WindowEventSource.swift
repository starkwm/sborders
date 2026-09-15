import Foundation

private func receiveWindowEvent(
  _ code: UInt32,
  _ bytes: UnsafeRawPointer?,
  _ count: Int,
  _ context: UnsafeMutableRawPointer?
) {
  guard let event = WindowEvent.decode(code: code, data: bytes, count: count) else { return }
  WindowEventRelay.shared.send(event)
}

@MainActor
final class WindowEventSource {
  private static let codes: [UInt32] = [
    723, 804, 806, 807, 808, 811, 815, 816, 1322, 1325, 1326, 1401, 1508,
  ]

  private let api: SkyLight
  private var registered: [UInt32] = []

  init(api: SkyLight) { self.api = api }

  func start(handler: @escaping @Sendable (WindowEvent) -> Void) throws {
    WindowEventRelay.shared.install(handler)
    for code in Self.codes {
      let result = api.register(receiveWindowEvent, code, nil)
      guard result == 0 else {
        stop()
        throw MessageError.message("Cannot register WindowServer event \(code): \(result).")
      }
      registered.append(code)
    }
  }

  func stop() {
    WindowEventRelay.shared.install(nil)
    for code in registered { _ = api.unregister(receiveWindowEvent, code, nil) }
    registered = []
  }
}

struct WindowEvent: Sendable, Equatable {
  enum Kind: Sendable { case refresh, changed, closed, focus, spaces }

  static func decode(code: UInt32, data: UnsafeRawPointer?, count: Int) -> WindowEvent? {
    if code == 1401 { return WindowEvent(kind: .spaces, windowID: nil) }
    if code == 1508 { return WindowEvent(kind: .focus, windowID: nil) }
    let offset = [1325, 1326].contains(code) ? 8 : 0
    guard let data, count >= offset + 4 else { return nil }
    let id = data.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
    guard id != 0 else { return nil }
    let kind: Kind = code == 1326 ? .closed : .changed
    return WindowEvent(kind: kind, windowID: id)
  }
  let kind: Kind
  let windowID: UInt32?
}

/// A process-lifetime callback destination avoids borrowing a released Swift object
/// if WindowServer finishes a callback concurrently with unregistration.
private final class WindowEventRelay: @unchecked Sendable {
  static let shared = WindowEventRelay()

  private let lock = NSLock()
  private var handler: (@Sendable (WindowEvent) -> Void)?

  func install(_ handler: (@Sendable (WindowEvent) -> Void)?) {
    lock.withLock { self.handler = handler }
  }

  func send(_ event: WindowEvent) {
    let handler = lock.withLock { self.handler }
    handler?(event)
  }
}
