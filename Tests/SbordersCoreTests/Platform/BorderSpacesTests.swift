import CoreGraphics
import StarkSkyLight
import Testing

@testable import SbordersCore

@Suite("BorderSpaces")
@MainActor
struct BorderSpacesTests {
  @Test("Uses each display's visible Space even when focus is missing")
  func visibility() throws {
    let client = Query()
    var spaces = BorderSpaces(client: client)
    #expect(try spaces.refresh() == [10, 20])
    let ordinary = spaces.membership(of: 1, ordered: true, sticky: false)
    #expect(ordinary.ids == [10, 20])
    #expect(ordinary.visible)
    #expect(ordinary.fullscreen)

    client.members = []
    #expect(!spaces.membership(of: 1, ordered: true, sticky: false).visible)
    client.members = nil
    let sticky = spaces.membership(of: 1, ordered: true, sticky: true)
    #expect(sticky.ids.isEmpty)
    #expect(sticky.visible)
    #expect(!sticky.fullscreen)
    #expect(!spaces.membership(of: 1, ordered: false, sticky: true).visible)
  }

  @Test("A failed refresh retains visibility and an empty list clears it")
  func refreshErrors() throws {
    let client = Query()
    var spaces = BorderSpaces(client: client)
    _ = try spaces.refresh()
    client.displays = nil
    #expect {
      try spaces.refresh()
    } throws: { error in
      (error as? MessageError)?.errorDescription == "Cannot read display Spaces."
    }
    #expect(spaces.membership(of: 1, ordered: true, sticky: false).visible)

    client.displays = []
    #expect {
      try spaces.refresh()
    } throws: { error in
      (error as? MessageError)?.errorDescription == "No desktop Spaces are available."
    }
    #expect(!spaces.membership(of: 1, ordered: true, sticky: false).visible)
  }
}

@MainActor
private final class Query: SpaceQuerying {
  var members: [SpaceID]? = [SpaceID(rawValue: 10), SpaceID(rawValue: 20)]
  var displays: [DisplaySpaces]? = [
    DisplaySpaces(
      id: DisplayID(rawValue: "A"),
      spaces: [Space(id: SpaceID(rawValue: 10), type: .desktop)],
      currentSpaceID: nil
    ),
    DisplaySpaces(
      id: DisplayID(rawValue: "B"),
      spaces: [Space(id: SpaceID(rawValue: 20), type: .fullscreen)],
      currentSpaceID: SpaceID(rawValue: 20)
    ),
  ]

  func snapshot() throws -> SpaceSnapshot {
    guard let displays else { throw SkyLightError.malformedResponse("displays") }
    return SpaceSnapshot(displays: displays, activeSpaceID: nil)
  }

  func activeSpace() throws -> SpaceID? { nil }
  func currentSpace(for displayID: DisplayID) throws -> SpaceID? { nil }

  func spaceIDs(containing windowID: CGWindowID) throws -> [SpaceID] {
    guard let members else { throw SkyLightError.queryFailed("membership") }
    return members
  }

  func spaceType(for spaceID: SpaceID) throws -> SpaceType {
    guard spaceID.rawValue == 20 else { throw SkyLightError.queryFailed("type") }
    return .fullscreen
  }
}
