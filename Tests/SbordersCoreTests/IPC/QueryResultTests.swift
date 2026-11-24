import Foundation
import StarkIPC
import Testing

@testable import SbordersCore

@Suite("QueryResult")
struct QueryResultTests {
  @Test("windows are ordered by ID and include focus and border state")
  func windows() throws {
    let front = window(id: 12, bundleID: "org.example.Editor")
    let back = window(id: 4, bundleID: nil)
    let border = BorderSnapshot(
      ids: [91, 84],
      frame: CGRect(x: -3, y: 5, width: 112, height: 72),
      visible: true,
      sublevel: -1,
      redrawCount: 3,
      transactionCount: 7,
      contextCreationCount: 2
    )

    let result = QueryResult.windows([(front, border), (back, nil)], focusedID: front.id)
    try expectResponse(
      result,
      json: """
        {"ok":true,"value":[
          {"window":{"id":4,"pid":105,"processName":"Editor","frame":[[1,9],[104,64]],
            "level":2,"sublevel":-1,"spaces":[7,3],"sticky":true,"visible":true,"fullscreen":false,
            "cornerRadius":8.5,"scale":2},
           "focused":false,"borderIDs":[],"borderVisible":false,
           "redrawCount":0,"transactionCount":0,"contextCreationCount":0},
          {"window":{"id":12,"pid":105,"bundleID":"org.example.Editor","processName":"Editor",
            "frame":[[1,9],[104,64]],"level":2,"sublevel":-1,"spaces":[7,3],"sticky":true,
            "visible":true,"fullscreen":false,"cornerRadius":8.5,"scale":2},
           "focused":true,"borderID":91,"borderIDs":[91,84],"borderFrame":[[-3,5],[112,72]],
           "borderVisible":true,"borderSublevel":-1,
           "redrawCount":3,"transactionCount":7,"contextCreationCount":2}
        ]}
        """
    )
  }

  @Test("diagnostics encode counters and omit absent errors and focus", arguments: [false, true])
  func diagnostics(hasDetails: Bool) throws {
    let result = QueryResult.diagnostics(
      Diagnostics(
        pid: 102,
        windowCount: 4,
        borderCount: 2,
        eventCount: 39,
        reconcileCount: 6,
        geometryQueryCount: 21,
        metadataQueryCount: 11,
        focusQueryCount: 7,
        configurationPath: "/config.jsonc",
        hasOverrides: true,
        configurationError: hasDetails ? "Invalid width" : nil,
        backendError: hasDetails ? "Cannot begin border transaction." : nil,
        focusMode: .accessibility,
        focusedWindowID: hasDetails ? 12 : nil,
        osVersion: "Test OS",
        missionControlActive: true
      )
    )
    let optionalFields =
      hasDetails
      ? """
      "configurationError":"Invalid width","backendError":"Cannot begin border transaction.",
      "focusedWindowID":12,
      """ : ""
    try expectResponse(
      result,
      json: """
        {"ok":true,"value":{"pid":102,"windowCount":4,"borderCount":2,"eventCount":39,
          "reconcileCount":6,"geometryQueryCount":21,"metadataQueryCount":11,"focusQueryCount":7,
          "configurationPath":"/config.jsonc","hasOverrides":true,\(optionalFields)
          "focusMode":"accessibility","osVersion":"Test OS","missionControlActive":true}}
        """
    )
  }

  @Test("config encodes the effective settings and schema key")
  func config() throws {
    var config = Configuration()
    config.schema = "config.schema.json"
    config.width = 7.5
    config.includeApps = [AppMatcher(processName: "Editor")]
    try expectResponse(
      .config(config),
      json: """
        {"ok":true,"value":{"$schema":"config.schema.json","enabled":true,"width":7.5,
          "style":"round","activeColor":"#E1E3E4","inactiveColor":"#00000000",
          "focusMode":"windowServer","includeApps":[{"processName":"Editor"}],"excludeApps":[]}}
        """
    )
  }

  private func expectResponse(
    _ result: QueryResult,
    json: String,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let data = try JSONEncoder().encode(result.response())
    let actual = try JSONDecoder().decode(JSONValue.self, from: data)
    let expected = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    #expect(actual == expected, sourceLocation: sourceLocation)
  }

  private func window(id: UInt32, bundleID: String?) -> WindowSnapshot {
    WindowSnapshot(
      id: id,
      pid: 105,
      bundleID: bundleID,
      processName: "Editor",
      frame: CGRect(x: 1, y: 9, width: 104, height: 64),
      level: 2,
      sublevel: -1,
      spaces: [7, 3],
      sticky: true,
      visible: true,
      fullscreen: false,
      cornerRadius: 8.5,
      scale: 2
    )
  }
}
