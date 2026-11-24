import Foundation
import StarkIPC

enum QueryResult {
  case config(Configuration)
  case windows([(window: WindowSnapshot, border: BorderSnapshot?)], focusedID: UInt32?)
  case diagnostics(Diagnostics)

  func response() throws -> ControlResponse {
    switch self {
    case .config(let configuration): return try encode(configuration)
    case .windows(let windows, let focusedID):
      let statuses = windows.sorted { $0.window.id < $1.window.id }.map { window, border in
        WindowStatus(
          window: window,
          focused: window.id == focusedID,
          borderID: border?.ids.first,
          borderIDs: border?.ids ?? [],
          borderFrame: border?.frame,
          borderVisible: border?.visible ?? false,
          borderSublevel: border?.sublevel,
          redrawCount: border?.redrawCount ?? 0,
          transactionCount: border?.transactionCount ?? 0,
          contextCreationCount: border?.contextCreationCount ?? 0
        )
      }
      return try encode(statuses)
    case .diagnostics(let diagnostics): return try encode(diagnostics)
    }
  }

  private func encode(_ value: some Encodable) throws -> ControlResponse {
    ControlResponse(
      value: try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    )
  }
}

struct BorderSnapshot {
  let ids: [UInt32]
  let frame: CGRect?
  let visible: Bool
  let sublevel: Int32?
  let redrawCount: Int
  let transactionCount: Int
  let contextCreationCount: Int
}

private struct WindowStatus: Encodable {
  let window: WindowSnapshot
  let focused: Bool
  let borderID: UInt32?
  let borderIDs: [UInt32]
  let borderFrame: CGRect?
  let borderVisible: Bool
  let borderSublevel: Int32?
  let redrawCount: Int
  let transactionCount: Int
  let contextCreationCount: Int
}

struct Diagnostics: Encodable {
  let pid: Int32
  let windowCount: Int
  let borderCount: Int
  let eventCount: Int
  let reconcileCount: Int
  let geometryQueryCount: Int
  let metadataQueryCount: Int
  let focusQueryCount: Int
  let configurationPath: String
  let hasOverrides: Bool
  let configurationError: String?
  let backendError: String?
  let focusMode: Configuration.FocusMode
  let focusedWindowID: UInt32?
  let osVersion: String
  let missionControlActive: Bool
}
