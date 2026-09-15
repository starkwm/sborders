import Foundation

public enum MessageError: LocalizedError, Sendable {
  case message(String)

  public var errorDescription: String? {
    switch self {
    case .message(let message): message
    }
  }
}
